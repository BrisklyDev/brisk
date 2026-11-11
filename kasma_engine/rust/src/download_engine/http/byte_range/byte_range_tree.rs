use crate::download_engine::http::byte_range::ByteRange;
use crate::engine_log;
use std::cell::RefCell;
use std::cmp::PartialEq;
use std::fmt::{Display, Formatter};
use std::rc::{Rc, Weak};
use strum_macros::{Display, EnumString};

pub type NodeRef = Rc<RefCell<ByteRangeNode>>;
type WeakNodeRef = Weak<RefCell<ByteRangeNode>>;

/// A tree implementation of byte ranges. Used for dynamic segmentation
/// of the download byte ranges associated with their designated connections.
/// When a download initially begins, it is started with one root node with
/// startByte = 0 and endByte = contentLength - 1 (inclusive). As the engine adds new connections,
/// the tree is further broken down into smaller segments, each associated with
/// a download connection.
///
/// Visual representation:
///
/// [0–1000]
/// ├── [0–500]
/// │   ├── [0–250]
/// │   └── [251–500]
/// └── [501–1000]
///     ├── [501–750]
///     └── [751–1000]
#[derive(Clone)]
pub struct ByteRangeTree {
    pub root: NodeRef,
    max_worker_number: u8,
    pub lowest_level_nodes: Vec<NodeRef>,
}

impl ByteRangeTree {
    pub fn new(root: NodeRef) -> Self {
        ByteRangeTree {
            lowest_level_nodes: vec![root.clone()],
            root,
            max_worker_number: 0,
        }
    }

    /// Builds a tree from missing byte ranges, and assigns proper worker numbers and statuses
    /// Example tree for a byte range with total_size of 600000 and missing_ranges of 30-70, 300-600:
    ///  [0-600000] (status: Outdated, worker: 0)
    ///     ├── [0-29] (status: Complete, worker: 0)
    ///     └── [30-600000] (status: Outdated, worker: 1)
    ///         ├── [30-70] (status: ToDownload, worker: 0)
    ///         └── [71-600000] (status: Outdated, worker: 0)
    ///             ├── [71-299] (status: Complete, worker: 0)
    ///             └── [300-600000] (status: Outdated, worker: 0)
    ///                 ├── [300-600] (status: ToDownload, worker: 1)
    ///                 └── [601-600000] (status: Complete, worker: 0)
    /// `total_size` is a byte count while every `ByteRange` end is an inclusive byte index,
    /// therefore the last valid byte is always `total_size - 1`.
    pub fn from_missing_bytes(
        total_size: u64,
        max_worker_count: u8,
        missing_ranges: Vec<ByteRange>,
    ) -> Self {
        let final_end = total_size.saturating_sub(1);
        let full_range = ByteRange::new(0, final_end);
        let root = ByteRangeNode::new(None, full_range, ByteRangeStatus::ToDownload, 0);
        let mut tree = Self::new(root);
        let missing_ranges: Vec<ByteRange> = missing_ranges
            .into_iter()
            .map(|r| ByteRange::new(r.start, r.end.min(final_end)))
            .filter(|r| r.start <= final_end && r.end >= r.start)
            .collect();
        if missing_ranges.is_empty() {
            return tree;
        }
        let first_range = missing_ranges[0].clone();
        if missing_ranges.len() == 1 && first_range.start == 0 && first_range.end == final_end {
            return tree;
        }
        let mut root_ref = tree.root.borrow_mut();

        if first_range.start != 0 {
            root_ref.create_left_child(
                ByteRange::new(0, first_range.start - 1),
                ByteRangeStatus::Complete,
                0,
            );
        } else {
            root_ref.create_left_child(
                ByteRange::new(0, first_range.end),
                ByteRangeStatus::ToDownload,
                0,
            );
        }

        root_ref.status = ByteRangeStatus::Outdated;
        root_ref.worker_number = 0;
        let right_child_start = root_ref.left_child.as_ref().unwrap().borrow().range.end + 1;
        root_ref.create_right_child(
            ByteRange::new(right_child_start, final_end),
            ByteRangeStatus::Outdated,
            1,
        );
        if let Some(right_child) = root_ref.right_child.as_ref() {
            right_child.borrow_mut().left_neighbor = root_ref.left_child.as_ref().map(Rc::clone);
        }
        if let Some(left_child) = root_ref.left_child.as_ref() {
            left_child.borrow_mut().right_neighbor = root_ref.right_child.as_ref().map(Rc::clone);
        }
        tree.max_worker_number = 1;
        tree.lowest_level_nodes.remove(0);
        tree.lowest_level_nodes
            .push(root_ref.left_child.as_ref().unwrap().clone());
        tree.lowest_level_nodes
            .push(root_ref.right_child.as_ref().unwrap().clone());

        if first_range.start == 0 && missing_ranges.len() == 1 {
            root_ref.right_child.as_ref().unwrap().borrow_mut().status = ByteRangeStatus::Complete;
            drop(root_ref);
            return tree;
        }

        let mut missing_ranges_clone = missing_ranges.clone();
        if first_range.start == 0 {
            // because it's already assigned
            missing_ranges_clone.remove(0);
        }
        let mut iteration_root = root_ref.right_child.clone().unwrap();
        // If the first missing range starts at 0, worker 0 has already been assigned to it.
        let mut current_max_worker_num: i16 = if first_range.start == 0 { 0 } else { -1 };
        while !missing_ranges_clone.is_empty() {
            let current_missing = missing_ranges_clone[0].clone();
            let mut exceeded_max_worker_num = false;
            let mut iteration_root_ref = iteration_root.borrow_mut();
            if iteration_root_ref.range.start == current_missing.start {
                if current_max_worker_num + 1 > max_worker_count as i16 - 1 {
                    exceeded_max_worker_num = true;
                } else {
                    current_max_worker_num += 1;
                }
                let status = if exceeded_max_worker_num {
                    ByteRangeStatus::ToDownloadInQueue
                } else {
                    ByteRangeStatus::ToDownload
                };
                iteration_root_ref.create_left_child(
                    current_missing.clone(),
                    status,
                    current_max_worker_num as u8,
                );
                let idx = missing_ranges_clone
                    .iter()
                    .position(|x| *x == current_missing)
                    .unwrap();
                missing_ranges_clone.remove(idx);
            } else {
                let l_child_start = iteration_root_ref.range.start;
                iteration_root_ref.create_left_child(
                    ByteRange::new(l_child_start, current_missing.start - 1),
                    ByteRangeStatus::Complete,
                    0,
                );
            }

            let status = if exceeded_max_worker_num {
                ByteRangeStatus::ToDownloadInQueue
            } else {
                ByteRangeStatus::Outdated
            };

            {
                let new_start = iteration_root_ref
                    .left_child
                    .as_ref()
                    .unwrap()
                    .borrow()
                    .range
                    .end
                    + 1;
                iteration_root_ref.create_right_child(
                    ByteRange::new(new_start, final_end),
                    status,
                    0,
                );
            }

            if let Some(right_child_rc) = iteration_root_ref.right_child.as_ref() {
                right_child_rc.borrow_mut().left_neighbor =
                    iteration_root_ref.left_child.as_ref().map(Rc::clone);
            }
            if let Some(left_child_rc) = iteration_root_ref.left_child.as_ref() {
                left_child_rc.borrow_mut().right_neighbor =
                    iteration_root_ref.right_child.as_ref().map(Rc::clone);
            }

            let idx = {
                let range_clone = iteration_root_ref.range.clone();
                drop(iteration_root_ref);
                let index = tree
                    .lowest_level_nodes
                    .iter()
                    .position(|x| x.borrow().range == range_clone)
                    .unwrap();
                iteration_root_ref = iteration_root.borrow_mut();
                index
            };
            tree.lowest_level_nodes.remove(idx);
            tree.lowest_level_nodes
                .insert(idx, iteration_root_ref.left_child.as_ref().unwrap().clone());
            tree.lowest_level_nodes.insert(
                idx + 1,
                iteration_root_ref.right_child.as_ref().unwrap().clone(),
            );
            if missing_ranges_clone.is_empty() {
                let mut right_child_ref = iteration_root_ref
                    .right_child
                    .as_ref()
                    .unwrap()
                    .borrow_mut();
                right_child_ref.status = ByteRangeStatus::Complete;
                if right_child_ref.range.start > final_end {
                    let idx = {
                        let r_child_range = right_child_ref.range.clone();
                        drop(right_child_ref);
                        drop(iteration_root_ref);
                        let index = tree
                            .lowest_level_nodes
                            .iter()
                            .position(|x| x.borrow().range == r_child_range)
                            .unwrap();
                        iteration_root_ref = iteration_root.borrow_mut();
                        index
                    };
                    tree.lowest_level_nodes.remove(idx);
                    iteration_root_ref.right_child = None;
                }
            }
            if iteration_root_ref.right_child.is_none() {
                break;
            }
            drop(iteration_root_ref);
            let next_node = iteration_root
                .borrow()
                .right_child
                .as_ref()
                .unwrap()
                .clone();
            iteration_root = next_node;
        }

        drop(root_ref);

        let mut initial_nodes: Vec<NodeRef> = tree
            .lowest_level_nodes
            .iter()
            .filter(|x| x.borrow().status == ByteRangeStatus::ToDownload)
            .cloned()
            .collect();

        let mut worker_num = initial_nodes
            .iter()
            .map(|node| node.borrow().worker_number)
            .max()
            .unwrap_or(0);
        tree.max_worker_number = worker_num;
        if initial_nodes.is_empty() || initial_nodes.len() >= max_worker_count as usize {
            return tree;
        }

        'outer: while worker_num <= max_worker_count {
            initial_nodes = tree
                .lowest_level_nodes
                .iter()
                .filter(|x| x.borrow().status == ByteRangeStatus::ToDownload)
                .cloned()
                .collect();
            for node in initial_nodes {
                if worker_num + 1 >= max_worker_count {
                    break 'outer;
                }
                let result = tree.split_byte_range_node(&node, false);
                if result.is_err() {
                    break 'outer;
                }
                if !result.unwrap() {
                    break 'outer;
                }
                worker_num += 1;
                node.borrow_mut()
                    .right_child
                    .as_ref()
                    .unwrap()
                    .borrow_mut()
                    .worker_number = worker_num;
            }
        }
        tree.max_worker_number = worker_num;
        tree
    }

    pub fn max_worker_number(&self) -> u8 {
        self.max_worker_number
    }

    pub fn split_byte_range_node(
        &mut self,
        node: &NodeRef,
        set_worker_num: bool,
    ) -> Result<bool, String> {
        let node_range = node.borrow().range.clone();
        {
            let n = node.borrow();
            if n.left_child.is_some() || n.right_child.is_some() {
                return Err(format!("Node {} is not a leaf node", node_range));
            }
        }
        let node_idx = self
            .lowest_level_nodes
            .iter()
            .position(|x| Rc::ptr_eq(x, node) || x.borrow().range == node_range);
        let Some(index) = node_idx else {
            return Err(format!(
                "Failed to find leaf node index for {}",
                node_range
            ));
        };
        if node_range.end <= node_range.start {
            return Err("Split byte is zero".to_string());
        }
        let split_byte = (node_range.end - node_range.start) / 2;
        if split_byte == 0 {
            return Err("Split byte is zero".to_string());
        }
        if node.borrow().status == ByteRangeStatus::Complete {
            return Ok(false);
        }

        let (range_left, range_right) = {
            let range_left: ByteRange;
            let range_right: ByteRange;
            if node_range.start > split_byte {
                let end_byte = split_byte + node_range.start;
                range_left = ByteRange::new(node_range.start, end_byte);
                range_right = ByteRange::new(end_byte + 1, node_range.end);
            } else {
                range_left = ByteRange::new(node_range.start, split_byte);
                range_right = ByteRange::new(split_byte + 1, node_range.end);
            }
            if !range_left.is_valid()
                || !range_right.is_valid()
                || range_left.len() < 8192
                || range_right.len() < 8192
            {
                return Err("range was invalid".to_string());
            }
            (range_left, range_right)
        };

        let mut node_ref = node.borrow_mut();
        let previous_left_neighbor = node_ref.left_neighbor.clone();
        let previous_right_neighbor = node_ref.right_neighbor.clone();
        node_ref.right_child = Some(ByteRangeNode::new(
            Some(Rc::downgrade(&node)),
            range_right,
            ByteRangeStatus::ToDownload,
            0,
        ));
        node_ref.left_child = Some(ByteRangeNode::new(
            Some(Rc::downgrade(&node)),
            range_left,
            ByteRangeStatus::ToDownload,
            0,
        ));

        {
            let mut left_child_ref = node_ref.left_child.as_ref().unwrap().borrow_mut();
            let mut right_child_ref = node_ref.right_child.as_ref().unwrap().borrow_mut();
            left_child_ref.left_neighbor = previous_left_neighbor.clone();
            left_child_ref.right_neighbor = node_ref.right_child.clone();
            right_child_ref.left_neighbor = node_ref.left_child.clone();
            right_child_ref.right_neighbor = previous_right_neighbor.clone();
            left_child_ref.worker_number = node_ref.worker_number;
            if set_worker_num {
                self.max_worker_number += 1;
                right_child_ref.worker_number = self.max_worker_number;
            }
        }
        if let Some(prev_left) = previous_left_neighbor {
            prev_left.borrow_mut().right_neighbor = node_ref.left_child.clone();
        }
        if let Some(prev_right) = previous_right_neighbor {
            prev_right.borrow_mut().left_neighbor = node_ref.right_child.clone();
        }

        self.lowest_level_nodes.remove(index);
        self.lowest_level_nodes
            .insert(index, node_ref.left_child.as_ref().unwrap().clone());
        self.lowest_level_nodes
            .insert(index + 1, node_ref.right_child.as_ref().unwrap().clone());
        Ok(true)
    }

    /// Splits the non-complete lowest level nodes into new byte ranges, creating at most
    /// `max_splits` new nodes. Returns the left children of the nodes that were split. The left
    /// child of each split node keeps the worker number of its parent (the worker that has to
    /// refresh its byte range) while the right child is assigned a new worker number.
    pub fn split(&mut self, max_splits: usize) -> Vec<NodeRef> {
        let mut split_nodes = vec![];
        if max_splits == 0 {
            return split_nodes;
        }
        let nodes_to_split: Vec<NodeRef> = self
            .lowest_level_nodes
            .iter()
            .filter(|n| {
                matches!(
                    n.borrow().status,
                    ByteRangeStatus::Downloading | ByteRangeStatus::ToDownload
                )
            })
            .cloned()
            .collect();
        for node in nodes_to_split {
            if split_nodes.len() >= max_splits {
                break;
            }
            if let Ok(true) = self.split_byte_range_node(&node, true) {
                if let Some(left) = node.borrow().left_child.clone() {
                    split_nodes.push(left);
                }
            }
        }
        split_nodes
    }

    pub fn search_node<T: AsRef<ByteRange>>(&self, target: T) -> Option<NodeRef> {
        let node_in_lowest_vec = self
            .lowest_level_nodes
            .iter()
            .find(|x| x.borrow().range == *target.as_ref());

        if node_in_lowest_vec.is_some() {
            return node_in_lowest_vec.cloned();
        }

        self.search_node_recursive(target.as_ref(), Some(self.root.clone()))
    }

    pub fn lowest_level_nodes_by_status(&self, status: ByteRangeStatus) -> Vec<NodeRef> {
        self.lowest_level_nodes
            .iter()
            .filter(|n| n.borrow().status == status)
            .cloned()
            .collect::<Vec<NodeRef>>()
    }

    fn search_node_recursive(
        &self,
        target: &ByteRange,
        current_node: Option<NodeRef>,
    ) -> Option<NodeRef> {
        let current_node = current_node?.clone();

        // Direct match
        if target == &current_node.borrow().range {
            return Some(current_node);
        }

        let node_borrow = current_node.borrow();
        let r_child = node_borrow.right_child.clone();
        let l_child = node_borrow.left_child.clone();

        if r_child.is_none() || l_child.is_none() {
            return None;
        }

        if let Some(l) = &l_child {
            if target.is_in_range_of(&l.borrow().range) {
                return self.search_node_recursive(target, Some(l.clone()));
            }
        }

        if let Some(r) = &r_child {
            if target.is_in_range_of(&r.borrow().range) {
                return self.search_node_recursive(target, Some(r.clone()));
            }
        }

        None
    }

    fn build_tree_str(&self, node: &NodeRef, prefix: String, is_last: bool, buffer: &mut String) {
        let connector = if is_last { "└──" } else { "├──" };
        let node_ref = node.borrow();
        let range = &node_ref.range;
        let worker = node_ref.worker_number;
        let status = node_ref.status;
        buffer.push_str(
            format!(
                "{}{} [{}-{}] (status: {}, worker: {})",
                prefix, connector, range.start, range.end, status, worker
            )
            .as_str(),
        );
        buffer.push('\n');

        let children: Vec<&NodeRef> = [node_ref.left_child.as_ref(), node_ref.right_child.as_ref()]
            .into_iter()
            .flatten()
            .collect();

        for i in 0..children.len() {
            let mut new_prefix = prefix.clone();
            if is_last {
                new_prefix.push_str("    ");
            } else {
                new_prefix.push_str("│   ");
            }
            self.build_tree_str(children[i], new_prefix, i == children.len() - 1, buffer);
        }
    }
}

impl Display for ByteRangeTree {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        let mut buffer = String::new();
        self.build_tree_str(&self.root, "".to_string(), true, &mut buffer);
        f.write_str(&buffer)
    }
}

pub struct ByteRangeNode {
    pub self_ref: WeakNodeRef,
    pub parent: WeakNodeRef,
    pub range: ByteRange,
    pub worker_number: u8,
    pub status: ByteRangeStatus,
    pub right_child: Option<NodeRef>,
    pub left_child: Option<NodeRef>,
    pub right_neighbor: Option<NodeRef>,
    pub left_neighbor: Option<NodeRef>,
}

impl ByteRangeNode {
    pub fn create_right_child(
        &mut self,
        byte_range: ByteRange,
        status: ByteRangeStatus,
        worker_number: u8,
    ) {
        let child = Self::new(
            Some(self.self_ref.clone()),
            byte_range,
            status,
            worker_number,
        );
        self.right_child = Some(child);
    }

    pub fn create_left_child(
        &mut self,
        byte_range: ByteRange,
        status: ByteRangeStatus,
        worker_number: u8,
    ) {
        let child = Self::new(
            Some(self.self_ref.clone()),
            byte_range,
            status,
            worker_number,
        );
        self.left_child = Some(child);
    }

    pub fn remove_children(&mut self) {
        self.right_child = None;
        self.left_child = None;
    }

    pub fn new(
        parent: Option<WeakNodeRef>,
        range: ByteRange,
        status: ByteRangeStatus,
        worker_number: u8,
    ) -> NodeRef {
        let node = Rc::new(RefCell::new(ByteRangeNode {
            self_ref: Weak::new(),
            parent: if parent.is_none() {
                Weak::new()
            } else {
                parent.unwrap()
            },
            range,
            worker_number,
            status,
            right_child: None,
            left_child: None,
            right_neighbor: None,
            left_neighbor: None,
        }));
        node.borrow_mut().self_ref = Rc::downgrade(&node);
        node
    }
}

/// Status ToDownload: Missing nodes (to be downloaded)
/// Status Complete: Nodes with ranges that already exist (not missing)
/// Status Outdated: Nodes that have been split and are now outdated
/// Status ToDownloadInQueue: Missing nodes (to be downloaded) with the difference being that InQueue
/// is set in cases where there already exist a maximum number (max_worker_number) of nodes created
/// with status ToDownload. Therefore, those initial nodes are assigned to workers, and when finished,
/// the engine takes new ranges from the ToDownloadInQueue status to assign to workers.
#[derive(PartialEq, Copy, Clone, Debug, Display, EnumString)]
pub enum ByteRangeStatus {
    ToDownload,
    Stopped,
    RefreshRequested,
    Downloading,
    ToDownloadInQueue,
    ReuseRequested,
    Outdated,
    Complete,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lowest(tree: &ByteRangeTree) -> Vec<(u64, u64, ByteRangeStatus, u8)> {
        tree.lowest_level_nodes
            .iter()
            .map(|n| {
                let n = n.borrow();
                (n.range.start, n.range.end, n.status, n.worker_number)
            })
            .collect()
    }

    /// Lowest level nodes must cover 0..=size-1 contiguously without overlaps.
    fn assert_covers(tree: &ByteRangeTree, size: u64) {
        let nodes = lowest(tree);
        let mut next = 0;
        for (start, end, _, _) in &nodes {
            assert_eq!(*start, next, "gap/overlap in {:?}", nodes);
            assert!(end >= start);
            next = end + 1;
        }
        assert_eq!(next, size, "tree does not end at size - 1: {:?}", nodes);
    }

    #[test]
    fn fresh_tree_uses_inclusive_end() {
        let tree = ByteRangeTree::from_missing_bytes(1000, 8, vec![ByteRange::new(0, 999)]);
        assert_eq!(lowest(&tree), vec![(0, 999, ByteRangeStatus::ToDownload, 0)]);
        // legacy non-inclusive end is normalized
        let tree = ByteRangeTree::from_missing_bytes(1000, 8, vec![ByteRange::new(0, 1000)]);
        assert_eq!(lowest(&tree), vec![(0, 999, ByteRangeStatus::ToDownload, 0)]);
    }

    #[test]
    fn resume_tree_assigns_unique_workers() {
        let size = 60_000_000;
        let missing = vec![
            ByteRange::new(0, 4_999_999),
            ByteRange::new(10_000_000, 14_999_999),
            ByteRange::new(30_000_000, 34_999_999),
            ByteRange::new(50_000_000, size - 1),
        ];
        let tree = ByteRangeTree::from_missing_bytes(size, 8, missing);
        assert_covers(&tree, size);
        let mut workers: Vec<u8> = lowest(&tree)
            .into_iter()
            .filter(|n| n.2 == ByteRangeStatus::ToDownload)
            .map(|n| n.3)
            .collect();
        let count = workers.len();
        assert_eq!(count, 8);
        workers.sort();
        workers.dedup();
        assert_eq!(workers.len(), count, "duplicate worker numbers");
        assert!(workers.iter().all(|w| *w < 8));
        assert_eq!(tree.max_worker_number(), 7);
    }

    #[test]
    fn resume_tree_queues_ranges_beyond_max_workers() {
        let size = 10_000_000;
        let missing: Vec<ByteRange> = (0..5)
            .map(|i| ByteRange::new(i * 2_000_000 + 1_000_000, i * 2_000_000 + 1_999_999))
            .collect();
        let tree = ByteRangeTree::from_missing_bytes(size, 2, missing);
        assert_covers(&tree, size);
        let nodes = lowest(&tree);
        let to_download = nodes.iter().filter(|n| n.2 == ByteRangeStatus::ToDownload).count();
        let queued = nodes
            .iter()
            .filter(|n| n.2 == ByteRangeStatus::ToDownloadInQueue)
            .count();
        assert_eq!(to_download, 2);
        assert_eq!(queued, 3);
    }

    #[test]
    fn split_is_bounded_and_keeps_coverage() {
        let size = 80_000_000;
        let mut tree = ByteRangeTree::from_missing_bytes(size, 8, vec![ByteRange::new(0, size - 1)]);
        tree.root.borrow_mut().status = ByteRangeStatus::Downloading;
        assert_eq!(tree.split(1).len(), 1);
        for n in &tree.lowest_level_nodes {
            n.borrow_mut().status = ByteRangeStatus::Downloading;
        }
        assert_eq!(tree.split(1).len(), 1);
        assert_eq!(tree.lowest_level_nodes.len(), 3);
        for n in &tree.lowest_level_nodes {
            n.borrow_mut().status = ByteRangeStatus::Downloading;
        }
        assert_eq!(tree.split(10).len(), 3);
        assert_covers(&tree, size);
        // neighbors are linked left to right
        let first = tree.lowest_level_nodes[0].clone();
        let mut cursor = Some(first);
        let mut count = 0;
        while let Some(node) = cursor {
            count += 1;
            cursor = node.borrow().right_neighbor.clone();
        }
        assert_eq!(count, tree.lowest_level_nodes.len());
    }

    #[test]
    fn search_node_finds_split_parent() {
        let size = 10_000_000;
        let mut tree = ByteRangeTree::from_missing_bytes(size, 8, vec![ByteRange::new(0, size - 1)]);
        let root = tree.root.clone();
        tree.split_byte_range_node(&root, true).unwrap();
        assert!(tree.search_node(ByteRange::new(0, size - 1)).is_some());
        let left = tree.lowest_level_nodes[0].borrow().range.clone();
        assert!(tree.search_node(&left).is_some());
        // splitting a non leaf node is refused
        assert!(tree.split_byte_range_node(&root, true).is_err());
    }
}
