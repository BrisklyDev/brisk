pub mod byte_range_tree;

use hyper::header::RANGE;
use std::cmp::Ordering;
use std::fmt;

#[derive(Clone, Debug)]
pub struct ByteRange {
    pub start: u64,
    pub end: u64,
}

impl ByteRange {
    pub fn new(start: u64, end: u64) -> Self {
        ByteRange { start, end }
    }

    pub fn empty() -> Self {
        ByteRange { start: 0, end: 0 }
    }

    /// Returns true if `self` is fully contained within `other`.
    pub fn is_in_range_of(&self, other: &ByteRange) -> bool {
        self.start >= other.start && self.end <= other.end
    }

    pub fn overlaps_with(&self, other: &ByteRange) -> bool {
        self.start <= other.start && self.end >= other.start
    }

    /// Symmetric overlap check. Both ranges are inclusive.
    pub fn overlaps(&self, other: &ByteRange) -> bool {
        self.start <= other.end && other.start <= self.end
    }

    pub fn is_valid(&self) -> bool {
        self.start != self.end && self.start < self.end && self.start + 1 < self.end
    }

    pub fn len(&self) -> u64 {
        self.end - self.start + 1
    }

    pub fn to_header(&self) -> (String, String) {
        (
            RANGE.to_string(),
            format!("bytes={}-{}", self.start, self.end),
        )
    }
}

impl PartialEq for ByteRange {
    fn eq(&self, other: &Self) -> bool {
        self.start == other.start && self.end == other.end
    }
}

impl fmt::Display for ByteRange {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "ByteRange::{}-{}", self.start, self.end)
    }
}

impl AsRef<ByteRange> for ByteRange {
    fn as_ref(&self) -> &ByteRange {
        self
    }
}

impl Eq for ByteRange {}

impl PartialOrd for ByteRange {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for ByteRange {
    fn cmp(&self, other: &Self) -> Ordering {
        match self.start.cmp(&other.start) {
            Ordering::Equal => self.end.cmp(&other.end),
            ord => ord,
        }
    }
}
