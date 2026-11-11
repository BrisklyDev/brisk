use crate::download_engine::EngineState;
use crate::download_engine::http::byte_range::ByteRange;
use crate::download_engine::http::byte_range::byte_range_tree::{
    ByteRangeStatus, ByteRangeTree, NodeRef,
};
use crate::download_engine::http::fetch_file_info;
use crate::download_engine::http::http_download_worker::Status;
use crate::download_engine::http::message::{
    DownloadCommand, EngineToMainMsg, EngineToWorkerMsg, ProgressReport, SegmentReport,
    ToEngineMessage, WorkerReport, WorkerToEngineMsg,
};
use crate::download_engine::http::progress::{DownloadProgress, WorkerProgress};
use crate::download_engine::http::rate_limiter::{RateLimiter, SharedRateLimiter};
use crate::download_engine::setting::DownloadSetting;
use crate::download_engine::utils::file::{
    TempFileMetadata, list_temp_files_sorted, resolve_versioned_file_path,
};
use crate::download_engine::utils::{format_remaining, now_millis};
use crate::download_engine::utils::sync_ext::MutexAnyhowExt;
use crate::download_engine::{
    DownloadInfo, DownloadItem, RunnableTask, http::http_download_worker::HttpDownloadWorker,
};
use crate::{engine_log, engine_warn, unwrap_or_bail};
use anyhow::{Ok, anyhow};
use std::collections::{HashMap, VecDeque};
use std::fs::{File, OpenOptions};
use std::io::{Read, Write};
use std::path::PathBuf;
use std::sync::{Arc, Mutex, MutexGuard};
use std::time::{Duration, Instant};
use std::rc::Rc;
use std::thread::JoinHandle;
use std::{fs, thread, u64, usize};
use tokio::fs::create_dir_all;
use tokio::io::AsyncWriteExt;
use tokio::sync::mpsc::{Receiver, Sender};
use tokio::time::interval;
use uuid::Uuid;

/// Defines the minimum allowed byte range length.
///
/// When a byte range is smaller than this, it will no longer be split and assigned to another worker,
/// preventing unreasonably small download requests.
pub const MINIMUM_DOWNLOADABLE_BYTE_RANGE_LEN: u64 = 500_000;

/// The interval duration at which the `worker_reuse_ticker` fires.
pub const WORKER_REUSE_TICKER_SECS: u64 = 1;

/// The interval duration at which the `worker_spawner_ticker` fires.
pub const WORKER_SPAWNER_TICKER_SECS: u64 = 2;

/// The interval duration at which the `worker_reset_ticker` fires.
pub const WORKER_RESET_TICKER_SECS: u64 = 1;

/// The interval duration at which the `log_flush_ticker` fires.
const LOG_FLUSH_TICKER_SECS: u64 = 1;

/// The maximum backoff delay between connection retries.
const MAX_RETRY_BACKOFF_MILLIS: u64 = 64_000;

/// The base retry delay for workers that reported a failure (instead of hanging).
const FAILED_WORKER_RETRY_BASE_MILLIS: u64 = 2_000;

/// The maximum number of times the engine restarts itself after an unrecoverable error
/// before giving up and reporting the download as failed.
const MAX_ENGINE_RESTARTS: u32 = 5;

/// Buffer size used when assembling the temp files into the final file.
const ASSEMBLE_BUFFER_SIZE: usize = 8 * 1024 * 1024;

/// The download engine is responsible for spawning download workers, coordinating byte range
/// assignments between workers, restarting hanging connections, validating the integrity of
/// temporary files, assembling the final file, and more.
///
/// Essentially, it runs as an async Tokio task that manages, coordinates, and closely monitors
/// the entire download process.
pub struct HttpDownloadEngine {
    download_item: DownloadItem,
    state: EngineState,
    setting: DownloadSetting,
    from_main_rx: Receiver<DownloadCommand>,
    to_main_tx: Sender<EngineToMainMsg>,
    log_buffer: String,
    pending_worker_handshakes: Vec<u8>,
    reuse_worker_queue: VecDeque<u8>,
    byte_range_tree: Option<ByteRangeTree>,
    workers: HashMap<u8, DownloadWorkerHandle>,
    assemble_requested: bool,
    progress: DownloadProgress,
    last_estimation_calc_time: u128,
    from_worker_tx: Sender<WorkerToEngineMsg>,
    from_worker_rx: Receiver<WorkerToEngineMsg>,
    spawned_workers: u8,
    rate_limiter: Option<SharedRateLimiter>,
    /// Whether the download has been paused by the user
    paused: bool,
    /// Number of times the engine has restarted itself due to unrecoverable errors
    restart_count: u32,
    /// Bytes on disk that belong to temp files of workers which are not spawned in this session
    /// (e.g. leftovers of a previous session). Used for accurate progress calculation.
    base_downloaded_bytes: u64,
    /// Whether a uid was explicitly provided. If not, a deterministic uid is derived from the
    /// url and file size so that the download can be resumed in a later session.
    uid_provided: bool,
    /// Highest received byte count reported per segment (keyed by start byte). Cleared on an
    /// engine reset, where the byte range tree is rebuilt from the temp files on disk.
    segment_high_water: HashMap<u64, u64>,
}

pub struct DownloadWorkerHandle {
    assigned_to_worker: bool,
    range: ByteRange,
    to_worker_tx: Sender<EngineToWorkerMsg>,
    engine_to_worker_rx: Option<Receiver<EngineToWorkerMsg>>,
    progress_arc: Arc<Mutex<WorkerProgress>>,
    awaiting_reset_response: bool,
    /// Number of consecutive resets sent to this worker without a successful connection
    reset_count: u32,
    /// Whether the worker reported a failure since its last reset
    failed: bool,
    join_handle: Option<JoinHandle<()>>,
}

/// Outcome of the engine's event loop
enum LoopExit {
    Complete(PathBuf),
    Terminated,
    Failed(String),
    NetworkError(String),
}

impl RunnableTask for HttpDownloadEngine {
    fn run(&mut self) {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(self.run_async());
    }
}
impl HttpDownloadEngine {
    pub fn new(
        from_main_rx: Receiver<DownloadCommand>,
        to_main_rx: Sender<EngineToMainMsg>,
        info: DownloadInfo,
        setting: DownloadSetting,
        output_file_name_override: Option<String>,
    ) -> (HttpDownloadEngine, String) {
        let uid_provided = info.uid.is_some();
        let uid = if let Some(uid) = info.uid {
            uid
        } else if let Some(size) = info.file_size {
            download_uid(&info.url, size)
        } else {
            Uuid::new_v4().to_string()
        };
        let item = DownloadItem {
            uid: uid.clone(),
            url: info.url,
            prefetched_info: info.file_size.is_some() && info.supports_range.is_some(),
            headers: info.headers,
            supports_range: if info.supports_range.is_some() {
                info.supports_range.unwrap()
            } else {
                false
            },
            file_size: if info.file_size.is_some() {
                info.file_size.unwrap()
            } else {
                0
            },
            file_name: if output_file_name_override.is_some() {
                output_file_name_override.unwrap()
            } else if info.filename.is_some() {
                info.filename.unwrap()
            } else {
                "".to_string()
            },
        };
        let (worker_to_engine_tx, worker_to_engine_rx) =
            tokio::sync::mpsc::channel::<WorkerToEngineMsg>(100);
        let rate_limiter = setting
            .speed_limit_bytes_per_sec
            .map(RateLimiter::shared);
        (
            HttpDownloadEngine {
                setting,
                state: EngineState::Initial,
                download_item: item,
                from_main_rx,
                log_buffer: String::new(),
                to_main_tx: to_main_rx,
                byte_range_tree: None,
                workers: HashMap::new(),
                progress: DownloadProgress::new(),
                last_estimation_calc_time: 0,
                spawned_workers: 0,
                assemble_requested: false,
                from_worker_rx: worker_to_engine_rx,
                from_worker_tx: worker_to_engine_tx,
                pending_worker_handshakes: Vec::new(),
                reuse_worker_queue: VecDeque::new(),
                rate_limiter,
                paused: false,
                restart_count: 0,
                base_downloaded_bytes: 0,
                uid_provided,
                segment_high_water: HashMap::new(),
            },
            uid,
        )
    }

    /// Runs the main async task of running the engine.
    ///
    /// If the download item lacks prefetched info, this method fetches the file metadata
    /// such as file size, support for range requests, and filename.
    ///
    /// It then starts the main event loop by calling `run_event_loop`.
    /// On success, it terminates workers and the engine itself.
    /// On failure, it tries to recover by performing an engine hard reset (terminating all
    /// workers and rebuilding the byte range tree from the temp files on disk).
    async fn run_async(&mut self) {
        if let Err(e) = self.init().await {
            engine_log!(self, "Failed to initialize engine! {}", e);
            let _ = self.flush_logs().await;
            let _ = self
                .to_main_tx
                .send(EngineToMainMsg::Failed(format!("{:#}", e)))
                .await;
            return;
        }
        let _ = self
            .to_main_tx
            .send(EngineToMainMsg::Uid(self.download_item.uid.clone()))
            .await;
        let _ = self
            .to_main_tx
            .send(EngineToMainMsg::Info {
                file_name: self.download_item.file_name.clone(),
                file_size: self.download_item.file_size,
                supports_range: self.download_item.supports_range,
            })
            .await;
        let exit = loop {
            match self.run_event_loop().await {
                Result::Ok(exit) => break exit,
                Err(e) => {
                    engine_log!(self, "Engine error: {:#}", e);
                    self.restart_count += 1;
                    if self.restart_count > MAX_ENGINE_RESTARTS {
                        break LoopExit::Failed(format!("{:#}", e));
                    }
                    engine_log!(
                        self,
                        "Restarting engine ({}/{})",
                        self.restart_count,
                        MAX_ENGINE_RESTARTS
                    );
                    self.reset_engine().await;
                }
            }
        };
        self.terminate_workers().await;
        let msg = match exit {
            LoopExit::Complete(path) => EngineToMainMsg::Complete(path),
            LoopExit::Terminated => EngineToMainMsg::Terminated,
            LoopExit::Failed(reason) => {
                engine_log!(self, "Download failed: {}", reason);
                EngineToMainMsg::Failed(reason)
            }
            LoopExit::NetworkError(reason) => {
                engine_log!(self, "Download failed: {}", reason);
                EngineToMainMsg::NetworkError(reason)
            }
        };
        let _ = self.flush_logs().await;
        let _ = self.to_main_tx.send(msg).await;
    }

    async fn init(&mut self) -> anyhow::Result<()> {
        if !self.download_item.prefetched_info {
            let info = fetch_file_info(self.download_item.url.clone()).await?;
            self.download_item.file_size = info.file_size;
            self.download_item.supports_range = info.supports_range;
            if self.download_item.file_name.is_empty() {
                self.download_item.file_name = info.file_name;
            }
            if !self.uid_provided {
                self.download_item.uid =
                    download_uid(&self.download_item.url, self.download_item.file_size);
            }
        }
        if self.download_item.file_size == 0 {
            anyhow::bail!("The server did not report the file size");
        }
        if self.download_item.file_name.is_empty() {
            self.download_item.file_name = self.download_item.uid.clone();
        }
        fs::create_dir_all(&self.setting.base_temp_dir)?;
        fs::create_dir_all(&self.setting.base_save_dir)?;
        if self.setting.logger_enabled {
            fs::create_dir_all(
                self.log_file_path()
                    .parent()
                    .expect("Failed to find parent for log file path")
                    .to_path_buf(),
            )?;
            OpenOptions::new()
                .append(true)
                .create(true)
                .open(self.log_file_path())?;
        }
        Ok(())
    }

    /// Terminates all spawned workers and waits for their threads to finish.
    ///
    /// The worker-to-engine channel is replaced first so that workers never block on sending
    /// messages to the engine and stale messages of terminated workers are discarded.
    async fn terminate_workers(&mut self) {
        let (tx, rx) = tokio::sync::mpsc::channel::<WorkerToEngineMsg>(100);
        self.from_worker_tx = tx;
        self.from_worker_rx = rx;
        for handle in self.workers.values() {
            let _ = handle.to_worker_tx.try_send(EngineToWorkerMsg::Terminate);
        }
        let handles: Vec<JoinHandle<()>> = self
            .workers
            .drain()
            .filter_map(|(_, mut h)| h.join_handle.take())
            .collect();
        for handle in handles {
            let _ = handle.join();
        }
    }

    /// Performs an engine hard reset: all workers are terminated and the engine state is
    /// cleared. The next call to [`Self::handle_start`] rebuilds the byte range tree from the
    /// temp files on disk.
    async fn reset_engine(&mut self) {
        self.terminate_workers().await;
        self.byte_range_tree = None;
        self.reuse_worker_queue.clear();
        self.pending_worker_handshakes.clear();
        self.assemble_requested = false;
        self.spawned_workers = 0;
        self.base_downloaded_bytes = 0;
        self.segment_high_water.clear();
        self.progress = DownloadProgress::new();
        self.state = EngineState::Initial;
    }

    /// Runs the engine's event loop.
    ///
    /// The event loop is an infinite loop over a `tokio::select!` with the following branches:
    /// - `self.from_main_rx.recv()`: listens to commands like pause/resume from the main thread.
    /// - `self.from_worker_rx.recv()`: listens to messages from download workers, typically responses to engine requests.
    /// - `worker_reuse_ticker.tick()`: ticker that reassigns idle workers to the remaining byte ranges.
    /// - `worker_spawner_ticker.tick()`: ticker that adds new connections dynamically during the download.
    /// - `worker_reset_ticker.tick()`: ticker that resets hanging connections.
    /// - `download_progress_ticker.tick()`: ticker that polls download progress and performs calculations
    ///   such as speed and time remaining.
    ///
    /// # Errors
    ///
    /// Returns an error if the event loop encounters a failure during execution.
    /// Such failures are handled in `run_async` by performing an engine hard reset.
    async fn run_event_loop(&mut self) -> anyhow::Result<LoopExit> {
        self.state = EngineState::Running;

        let mut worker_reuse_ticker = interval(Duration::from_secs(WORKER_REUSE_TICKER_SECS));
        let mut worker_spawner_ticker = interval(Duration::from_secs(WORKER_SPAWNER_TICKER_SECS));
        let mut log_flush_ticker = interval(Duration::from_secs(LOG_FLUSH_TICKER_SECS));
        let mut worker_reset_ticker = interval(Duration::from_secs(WORKER_RESET_TICKER_SECS));
        let mut download_progress_ticker = interval(Duration::from_millis(
            self.setting.progress_polling_frequency_millis,
        ));

        self.handle_start().await?;

        loop {
            if let EngineState::Complete = self.state {
                return Ok(LoopExit::Complete(self.output_file_path()));
            }
            if let Some(reason) = self.network_error() {
                return Ok(LoopExit::NetworkError(reason));
            }
            tokio::select! {
                biased;
                cmd = self.from_main_rx.recv() => match cmd {
                    Some(DownloadCommand::Start) => self.handle_start().await?,
                    Some(DownloadCommand::Pause) => self.pause_workers().await?,
                    Some(DownloadCommand::Terminate) | None => {
                        engine_log!(self, "Terminate command received");
                        let _ = self.send_to_assigned_workers(EngineToWorkerMsg::Stop).await;
                        return Ok(LoopExit::Terminated);
                    }
                },
                Some(msg) = self.from_worker_rx.recv() => self.handle_worker_msg(msg).await?,
                _ = worker_reuse_ticker.tick() => self.run_worker_reuse_ticker().await?,
                _ = worker_spawner_ticker.tick() => self.run_worker_spawner_ticker().await?,
                _ = worker_reset_ticker.tick() => self.run_worker_reset_ticker().await?,
                _ = download_progress_ticker.tick() => self.handle_progress_updates().await?,
                _ = log_flush_ticker.tick() => self.flush_logs().await?
            }
        }
    }

    /// Polls the overall download progress and calculates overall download speed, estimated time
    /// remaining. At the end, it also calls `assemble_file` if assemble eligible
    /// (all workers finished their downloads)
    ///
    async fn handle_progress_updates(&mut self) -> anyhow::Result<()> {
        if self.state == EngineState::Complete {
            return Ok(());
        }
        let total_bytes_speed = self.calculate_total_speed()?;
        let readable_speed = self.speed_in_bytes_to_readable_string(total_bytes_speed);
        let is_temp_write_complete = self.check_temp_write_completion()?;
        self.progress.total_download_progress = self.calculate_total_progress()?;
        self.progress.speed_bytes_per_sec = total_bytes_speed;
        self.progress.speed_str = readable_speed;
        self.calculate_estimated_remaining(total_bytes_speed)?;
        self.set_overall_download_status()?;
        if self.progress.total_download_progress > 1.0 {
            anyhow::bail!(
                "Fatal! Overall progress exceeded 1: {}",
                self.progress.total_download_progress
            )
        }
        if is_temp_write_complete && self.is_assemble_eligible() {
            let _ = self.to_main_tx.try_send(EngineToMainMsg::Assembling);
            if !self.assemble_file()? {
                anyhow::bail!("Failed to assemble the file");
            }
        }
        let report = ProgressReport {
            progress: self.progress.total_download_progress.min(1.0),
            downloaded_bytes: self.total_downloaded_bytes()?,
            total_bytes: self.download_item.file_size,
            speed_bytes_per_sec: total_bytes_speed,
            estimated_remaining_sec: self.progress.estimated_remaining_sec,
            estimated_remaining: self.progress.estimated_remaining.clone(),
            status: self.progress.status,
            active_workers: self.active_worker_count(),
            workers: self.worker_reports(),
            segments: self.segment_reports(),
        };
        // Never block the engine on a slow consumer. Progress reports are disposable.
        let _ = self.to_main_tx.try_send(EngineToMainMsg::Progress(report));

        Ok(())
    }

    fn worker_reports(&self) -> Vec<WorkerReport> {
        let mut reports: Vec<WorkerReport> = self
            .workers
            .iter()
            .filter(|(_, w)| w.assigned_to_worker)
            .filter_map(|(num, w)| {
                let p = w.progress_arc.lock().ok()?;
                Some(WorkerReport {
                    worker_number: *num,
                    status: p.status,
                    speed_bytes_per_sec: p.speed_bytes_per_sec,
                    range_start: w.range.start,
                    range_end: w.range.end,
                    range_received_bytes: range_bytes_for(&p, &w.range),
                })
            })
            .collect();
        reports.sort_by_key(|r| r.worker_number);
        reports
    }

    fn segment_reports(&mut self) -> Vec<SegmentReport> {
        let Some(tree) = self.byte_range_tree.as_ref() else {
            return vec![];
        };
        if !self.download_item.supports_range || self.download_item.file_size == 0 {
            return vec![];
        }
        // A split is made at the middle of a range without knowing how far its worker has
        // progressed. Until the worker confirms the refresh (which may move the split point),
        // the children are tentative, so their parent is reported instead.
        let mut display_nodes: Vec<NodeRef> = Vec::with_capacity(tree.lowest_level_nodes.len());
        for node in &tree.lowest_level_nodes {
            let parent = node.borrow().parent.upgrade();
            let shown = match parent {
                Some(p) if p.borrow().status == ByteRangeStatus::RefreshRequested => p,
                _ => node.clone(),
            };
            if !display_nodes.iter().any(|n| Rc::ptr_eq(n, &shown)) {
                display_nodes.push(shown);
            }
        }
        let mut nodes: Vec<SegmentReport> = display_nodes
            .iter()
            .map(|node| {
                let node = node.borrow();
                let range = &node.range;
                let complete = node.status == ByteRangeStatus::Complete;
                // Only a worker currently assigned to a range starting at this segment reports
                // its progress (a pending split shrinks the worker's range, not its start)
                let worker = self
                    .workers
                    .get(&node.worker_number)
                    .filter(|w| w.assigned_to_worker && w.range.start == range.start);
                let (received, active) = match worker.and_then(|w| w.progress_arc.lock().ok()) {
                    Some(p) => (
                        range_bytes_for(&p, range),
                        !complete && p.status == Status::Downloading,
                    ),
                    None => (0, false),
                };
                // Bytes of a segment never disappear while the engine runs (a split keeps the
                // start byte and only shrinks the end). Never report less than before, so that
                // momentary gaps (e.g. a worker reconnecting) don't move the bar backwards.
                let received = if complete {
                    range.len()
                } else {
                    let seen = self.segment_high_water.entry(range.start).or_insert(0);
                    *seen = (*seen).max(received);
                    (*seen).min(range.len())
                };
                SegmentReport {
                    start: range.start,
                    end: range.end,
                    worker_number: node.worker_number,
                    received_bytes: received,
                    complete,
                    active,
                }
            })
            .collect();
        nodes.sort_by_key(|s| s.start);
        // Fill the gaps (ranges that were downloaded in a previous session) with complete segments
        let mut segments = Vec::with_capacity(nodes.len() + 1);
        let mut next_start = 0u64;
        for node in nodes {
            if node.start > next_start {
                segments.push(SegmentReport {
                    start: next_start,
                    end: node.start - 1,
                    worker_number: 0,
                    received_bytes: node.start - next_start,
                    complete: true,
                    active: false,
                });
            }
            next_start = next_start.max(node.end.saturating_add(1));
            segments.push(node);
        }
        let file_size = self.download_item.file_size;
        if next_start < file_size {
            segments.push(SegmentReport {
                start: next_start,
                end: file_size - 1,
                worker_number: 0,
                received_bytes: file_size - next_start,
                complete: true,
                active: false,
            });
        }
        segments
    }

    fn active_worker_count(&self) -> usize {
        self.workers
            .values()
            .filter(|w| w.assigned_to_worker)
            .filter(|w| {
                w.progress_arc
                    .lock()
                    .map(|p| p.status == Status::Downloading)
                    .unwrap_or(false)
            })
            .count()
    }

    fn set_overall_download_status(&mut self) -> anyhow::Result<()> {
        let worker_progresses = self
            .workers
            .iter()
            .map(|w| w.1.progress_arc.lock_anyhow())
            .collect::<anyhow::Result<Vec<MutexGuard<WorkerProgress>>>>()?;

        let all_connecting = worker_progresses
            .iter()
            .all(|p| p.status == Status::Connecting);

        if self.paused {
            self.progress.status = Status::Stopped;
            return Ok(());
        }

        if all_connecting {
            self.progress.status = Status::Connecting;
            return Ok(());
        }

        let any_downloading = worker_progresses
            .iter()
            .any(|p| p.status == Status::Downloading);

        if any_downloading {
            self.progress.status = Status::Downloading;
        }

        Ok(())
    }

    fn speed_in_bytes_to_readable_string(&self, speed_bytes: u64) -> String {
        let speed_in_mega_bytes = speed_bytes as f64 / 1_000_000.0;
        let speed_in_kilo_bytes = speed_bytes as f64 / 1000.0;

        if speed_in_mega_bytes > 1.0 {
            format!("{:.2} MB/s", speed_in_mega_bytes)
        } else if speed_in_kilo_bytes > 1.0 {
            format!("{:.2} KB/s", speed_in_kilo_bytes)
        } else {
            format!("{:.2} B/s", speed_bytes)
        }
    }

    fn calculate_estimated_remaining(&mut self, bytes_speed: u64) -> anyhow::Result<()> {
        let progresses = self.worker_progresses()?;
        if progresses.is_empty()
            || self.last_estimation_calc_time + 1000 > now_millis()
            || bytes_speed == 0
        {
            return Ok(());
        }

        let total_bytes: u64 = progresses
            .iter()
            .map(|x| x.total_bytes_received)
            .sum::<u64>()
            + self.base_downloaded_bytes;
        if total_bytes > self.download_item.file_size {
            return Ok(());
        }
        let remaining_sec = (self.download_item.file_size - total_bytes) / bytes_speed;
        let estimated_remaining = format_remaining(remaining_sec);

        drop(progresses);

        self.last_estimation_calc_time = now_millis();
        self.progress.estimated_remaining = estimated_remaining;
        self.progress.estimated_remaining_sec = remaining_sec;

        Ok(())
    }

    /// Calculates the total progress based on the total received bytes instead of summing up the
    /// progress fractions of workers, which is prone to floating point errors.
    fn calculate_total_progress(&self) -> anyhow::Result<f64> {
        if self.download_item.file_size == 0 {
            return Ok(0.0);
        }
        Ok(self.total_downloaded_bytes()? as f64 / self.download_item.file_size as f64)
    }

    fn total_downloaded_bytes(&self) -> anyhow::Result<u64> {
        let workers_total: u64 = self
            .worker_progresses()?
            .iter()
            .map(|p| p.total_bytes_received)
            .sum();
        Ok(workers_total + self.base_downloaded_bytes)
    }

    fn worker_progresses(&self) -> anyhow::Result<Vec<MutexGuard<'_, WorkerProgress>>> {
        let progress_vec = self
            .workers
            .iter()
            .filter(|w| w.1.assigned_to_worker)
            .map(|w| w.1.progress_arc.lock_anyhow())
            .collect::<anyhow::Result<Vec<_>>>()?;

        Ok(progress_vec)
    }

    /// Once all byte ranges are reported complete, the temp files are validated. If corrupted
    /// temp files are found or byte ranges are missing, an error is returned which leads to an
    /// engine hard reset, re-downloading the missing ranges.
    fn check_temp_write_completion(&mut self) -> anyhow::Result<bool> {
        if self.state != EngineState::WorkersComplete {
            return Ok(false);
        }
        let bad_files_existed = self.validate_temp_files_integrity(true, true)?;
        if bad_files_existed {
            anyhow::bail!("Corrupted temp files were found and deleted");
        }
        let missing_ranges = self.find_missing_byte_ranges()?;
        for range in &missing_ranges {
            engine_log!(self, "Missing range:: {}", range);
        }
        if !missing_ranges.is_empty() {
            anyhow::bail!(
                "All workers completed but {} byte ranges are missing",
                missing_ranges.len()
            );
        }
        Ok(true)
    }

    fn calculate_total_speed(&self) -> anyhow::Result<u64> {
        let speed_bytes = self
            .worker_progresses()?
            .iter()
            .map(|x| x.speed_bytes_per_sec)
            .sum();
        Ok(speed_bytes)
    }

    /// Sends a reset command to the workers that have not responded in the last
    /// `reset_timeout_millis` milliseconds (or that reported a failure). The delay grows
    /// exponentially with each consecutive reset of the same worker.
    async fn run_worker_reset_ticker(&mut self) -> anyhow::Result<()> {
        if self.paused || self.state != EngineState::Running {
            return Ok(());
        }
        let now = now_millis();
        let max_retries = self.setting.max_connection_retry_count;
        let timeout = self.setting.reset_timeout_millis;
        let mut to_reset = vec![];
        for (worker_num, handle) in &self.workers {
            if !handle.assigned_to_worker {
                continue;
            }
            if let Some(max) = max_retries {
                if handle.reset_count >= max {
                    continue;
                }
            }
            let progress = handle.progress_arc.lock_anyhow()?;
            if matches!(
                progress.status,
                Status::Stopped | Status::Starting | Status::Complete | Status::RangeComplete
            ) {
                continue;
            }
            let base = if handle.failed {
                FAILED_WORKER_RETRY_BASE_MILLIS.min(timeout)
            } else {
                timeout
            };
            let delay = backoff_delay_millis(handle.reset_count, base);
            if progress.last_response_time + (delay as u128) < now {
                to_reset.push(*worker_num);
            }
        }
        for worker_num in to_reset {
            let handle = self.workers.get_mut(&worker_num).unwrap();
            handle.reset_count += 1;
            handle.failed = false;
            handle.awaiting_reset_response = true;
            if let Result::Ok(mut progress) = handle.progress_arc.lock() {
                // prevents sending another reset before the worker has had a chance to respond
                progress.last_response_time = now;
            }
            let reset_count = handle.reset_count;
            handle.to_worker_tx.send(EngineToWorkerMsg::Reset).await?;
            engine_log!(self, "Sent reset #{} to worker {}", reset_count, worker_num);
        }
        Ok(())
    }

    /// Returns an error reason if all active workers have exceeded the maximum retry count.
    fn network_error(&self) -> Option<String> {
        let max = self.setting.max_connection_retry_count?;
        if self.paused {
            return None;
        }
        let active: Vec<&DownloadWorkerHandle> = self
            .workers
            .values()
            .filter(|w| w.assigned_to_worker)
            .filter(|w| {
                w.progress_arc
                    .lock()
                    .map(|p| {
                        !matches!(
                            p.status,
                            Status::Stopped | Status::Complete | Status::RangeComplete
                        )
                    })
                    .unwrap_or(false)
            })
            .collect();
        let exhausted = !active.is_empty()
            && active.iter().all(|w| {
                w.reset_count >= max
                    && w.progress_arc
                        .lock()
                        .map(|p| {
                            let delay = backoff_delay_millis(
                                w.reset_count,
                                self.setting.reset_timeout_millis,
                            ) as u128;
                            p.last_response_time + delay < now_millis()
                        })
                        .unwrap_or(true)
            });
        if exhausted {
            Some(format!(
                "Network error: connection retries exceeded the maximum of {}",
                max
            ))
        } else {
            None
        }
    }

    /// Runs the dynamic worker reuse mechanism.
    ///
    /// Dynamic worker reuse is a mechanism which allows for updating the assigned byte range of workers,
    /// enabling the reuse of idle workers. It ensures that when a worker has finished downloading
    /// its designated range, it can assist another worker by downloading a portion of that
    /// workers' byte range. This makes sure that the maximum number of workers are as active as
    /// possible during the entire download process.
    async fn run_worker_reuse_ticker(&mut self) -> anyhow::Result<()> {
        if self.reuse_worker_queue.is_empty()
            || self.paused
            || self.state != EngineState::Running
            || !self.download_item.supports_range
            || self.byte_range_tree.is_none()
            || self.should_spawn_worker()
            || self.workers.iter().any(|w| w.1.awaiting_reset_response)
            || self.pending_range_refresh_exists()
            || self.progress.total_download_progress >= 1f64
        {
            return Ok(());
        }

        engine_log!(self, "Running worker reuse ticker...");
        let worker_num = self.reuse_worker_queue.pop_front().unwrap();
        self.request_byte_range_refresh_reuse_worker(worker_num)
            .await
    }

    /// Splits a byte range node and requests a byte range refresh based on the range
    /// of its left child.
    ///
    /// When a candidate node is selected and split, the worker that's assigned to that byte range
    /// will be asked to refresh its byte range based on the new value. The new value is the
    /// left_child of that split candidate node, a smaller range of that node. e.g. If the
    /// candidate node range is (0-1000), it is first split, resulting in:
    /// [0–1000]
    /// ├── [0–500]
    /// └── [501–1000]
    /// Then, the left_child's range (0-500) will be assigned as the new range of that worker.
    /// Therefore, when the worker's downloaded range exceeds the new end byte, the download is
    /// terminated and the overflow bytes are discarded. It is important to note that whether or
    /// not 0-500 will be used as the new range or a new suggested value will be used, is decided
    /// by the target worker. see: [`Self::handle_worker_msg`]
    ///
    /// Nodes waiting in queue (built from missing bytes on resume) are directly assigned to the
    /// idle worker without splitting, since no other worker is downloading them.
    ///
    /// This method merely sends the byte range request to the worker. The new worker that assists
    /// the target worker by downloading the new range is handled in [`Self::handle_worker_msg`]
    async fn request_byte_range_refresh_reuse_worker(
        &mut self,
        worker_num: u8,
    ) -> anyhow::Result<()> {
        let byte_range_tree = self.byte_range_tree.as_mut().unwrap();
        let worker_range = unwrap_or_bail!(
            self.workers.get(&worker_num),
            "request_byte_range_refresh_reuse_worker:: Fatal! Failed to find worker_num {} in list of workers",
            worker_num
        )
        .range
        .clone();

        let in_queue_nodes =
            byte_range_tree.lowest_level_nodes_by_status(ByteRangeStatus::ToDownloadInQueue);
        if let Some(node) = in_queue_nodes.first() {
            let range = {
                let mut n = node.borrow_mut();
                n.worker_number = worker_num;
                n.status = ByteRangeStatus::Downloading;
                n.range.clone()
            };
            engine_log!(
                self,
                "Assigning queued range {} to worker {}",
                range,
                worker_num
            );
            return self.send_start_command_reuse_worker(worker_num, range).await;
        }

        let mut nodes = byte_range_tree.lowest_level_nodes_by_status(ByteRangeStatus::Downloading);
        // Prefer the largest ranges as they benefit the most from being split
        nodes.sort_by(|a, b| b.borrow().range.len().cmp(&a.borrow().range.len()));

        // The target node must be assigned to a worker that is actively downloading it
        let target = nodes.iter().find_map(|node| {
            let range = node.borrow().range.clone();
            if range == worker_range || range.len() < MINIMUM_DOWNLOADABLE_BYTE_RANGE_LEN * 2 {
                return None;
            }
            self.workers
                .iter()
                .find(|w| {
                    w.1.assigned_to_worker && w.1.range == range && !w.1.awaiting_reset_response
                })
                .map(|w| (node.clone(), *w.0))
        });

        let Some((target_node, target_worker_num)) = target else {
            self.reuse_worker_queue.push_back(worker_num);
            engine_log!(
                self,
                "request_byte_range_refresh_reuse_worker:: No suitable target node found"
            );
            return Ok(());
        };
        let target_node_range = target_node.borrow().range.clone();

        engine_log!(
            self,
            "Splitting node worker_num::{} with range {}",
            worker_num,
            target_node_range
        );
        engine_log!(self, "Pre-split byte range tree:\n{}", byte_range_tree);
        let split_result = byte_range_tree.split_byte_range_node(&target_node, false);
        engine_log!(self, "Post-split byte range tree:\n{}", byte_range_tree);
        if !matches!(split_result, Result::Ok(true)) {
            self.reuse_worker_queue.push_back(worker_num);
            engine_warn!(
                self,
                "request_byte_range_refresh_reuse_worker:: Failed to split node worker_num {} with range {}",
                worker_num,
                target_node_range
            )
        }

        let left_child_range = {
            let target_node_borrow = target_node.borrow();
            if let Some(right_child) = target_node_borrow.right_child.as_ref() {
                let mut borrow = right_child.borrow_mut();
                borrow.worker_number = worker_num;
                borrow.status = ByteRangeStatus::ReuseRequested;
            }
            let left_child = target_node_borrow.left_child.as_ref().unwrap();
            left_child.borrow_mut().status = ByteRangeStatus::RefreshRequested;
            left_child.borrow().range.clone()
        };
        target_node.borrow_mut().status = ByteRangeStatus::RefreshRequested;

        engine_log!(
            self,
            "Sending refresh byte range request to worker {} with range {}",
            target_worker_num,
            left_child_range
        );

        self.workers[&target_worker_num]
            .to_worker_tx
            .send(EngineToWorkerMsg::RefreshByteRange(left_child_range, true))
            .await?;

        Ok(())
    }

    fn pending_range_refresh_exists(&self) -> bool {
        self.byte_range_tree.as_ref().is_some_and(|tree| {
            tree.lowest_level_nodes.iter().any(|n| {
                matches!(
                    n.borrow().status,
                    ByteRangeStatus::RefreshRequested | ByteRangeStatus::ReuseRequested
                )
            })
        })
    }

    async fn run_worker_spawner_ticker(&mut self) -> anyhow::Result<()> {
        if self.should_spawn_worker() {
            self.request_byte_range_refresh_new_worker().await?
        }
        Ok(())
    }

    /// Splits the byte ranges of the active workers in order to spawn new workers. The number of
    /// splits is bounded by the remaining worker slots. Each worker whose range has been split is
    /// asked to refresh its range to the left half. The new worker for the right half is spawned
    /// once the refresh is confirmed (see [`Self::handle_refresh_byte_range_success`]).
    async fn request_byte_range_refresh_new_worker(&mut self) -> anyhow::Result<()> {
        if self.byte_range_tree.is_none() {
            return Ok(());
        }
        let total = self.setting.total_connections as usize;
        let byte_range_tree = self.byte_range_tree.as_mut().unwrap();
        let remaining_slots = total
            .saturating_sub(self.spawned_workers as usize)
            .saturating_sub(self.pending_worker_handshakes.len())
            .min(total.saturating_sub(byte_range_tree.max_worker_number() as usize + 1));
        if remaining_slots == 0 {
            return Ok(());
        }
        engine_log!(self, "Pre-split byte range tree:\n{}", byte_range_tree);
        let split_nodes = byte_range_tree.split(remaining_slots);
        engine_log!(self, "Post-split byte range tree:\n{}", byte_range_tree);
        if split_nodes.is_empty() {
            // Ranges are too small to be split any further
            self.spawned_workers = self.setting.total_connections;
            return Ok(());
        }
        engine_log!(self, "Refreshing worker ranges...");
        for node in split_nodes {
            let (worker_number, range) = {
                let n = node.borrow();
                (n.worker_number, n.range.clone())
            };
            let Some(handle) = self.workers.get(&worker_number) else {
                engine_log!(self, "Fatal! worker {} not found for refresh", worker_number);
                continue;
            };
            if !handle.assigned_to_worker || !handle.range.overlaps(&range) {
                engine_log!(
                    self,
                    "Fatal! refresh range {} does not overlap worker {} range {}",
                    range,
                    worker_number,
                    handle.range
                );
                continue;
            }
            node.borrow_mut().status = ByteRangeStatus::RefreshRequested;
            if let Some(parent) = node.borrow().parent.upgrade() {
                parent.borrow_mut().status = ByteRangeStatus::RefreshRequested;
            }
            engine_log!(
                self,
                "sending refresh range {} to worker {}",
                range,
                worker_number
            );
            handle
                .to_worker_tx
                .send(EngineToWorkerMsg::RefreshByteRange(range, false))
                .await?;
        }
        Ok(())
    }

    fn should_spawn_worker(&self) -> bool {
        if self.byte_range_tree.is_none() {
            return false;
        }
        self.download_item.supports_range
            && !self.paused
            && self.state == EngineState::Running
            && !self.pending_range_refresh_exists()
            && self.progress.estimated_remaining_sec > 3
            && self.pending_worker_handshakes.is_empty()
            && self.spawned_workers < self.setting.total_connections
    }

    async fn pause_workers(&mut self) -> anyhow::Result<()> {
        if self.paused || self.state != EngineState::Running {
            return Ok(());
        }
        engine_log!(self, "Pausing download");
        self.send_to_assigned_workers(EngineToWorkerMsg::Stop)
            .await?;
        self.paused = true;
        self.progress.status = Status::Stopped;
        let _ = self.to_main_tx.try_send(EngineToMainMsg::Paused);
        Ok(())
    }

    /// Handles the messages coming from download workers
    ///
    ///
    async fn handle_worker_msg(&mut self, msg: WorkerToEngineMsg) -> anyhow::Result<()> {
        match msg.message {
            ToEngineMessage::Complete(range) => {
                self.handle_range_download_completion(msg.worker_number, range)?;
            }
            ToEngineMessage::ByteRangeRefreshSuccess {
                requested_range,
                reuse,
            } => {
                self.handle_refresh_byte_range_success(msg.worker_number, requested_range, reuse)
                    .await?
            }
            ToEngineMessage::ByteRangeRefreshRefused {
                requested_range,
                reuse,
            } => {
                self.handle_refresh_byte_range_refused(msg.worker_number, requested_range, reuse)
                    .await?;
            }
            ToEngineMessage::ByteRangeRefreshOverlapped {
                requested_range,
                refreshed_range,
                new_valid_range,
                reuse,
            } => {
                self.handle_refresh_byte_range_overlap(
                    msg.worker_number,
                    requested_range,
                    refreshed_range,
                    new_valid_range,
                    reuse,
                )
                .await?;
            }
            ToEngineMessage::Stopped => self.handle_stopped_message(msg.worker_number)?,
            ToEngineMessage::Failed => {
                engine_log!(self, "Worker {} reported a failure", msg.worker_number);
                if let Some(handle) = self.workers.get_mut(&msg.worker_number) {
                    handle.failed = true;
                    handle.awaiting_reset_response = false;
                    if let Result::Ok(mut p) = handle.progress_arc.lock() {
                        p.last_response_time = now_millis();
                        p.speed_bytes_per_sec = 0;
                    }
                }
            }
            ToEngineMessage::HandshakeResponse { reuse } => {
                self.handle_worker_handshake(msg.worker_number, reuse)
            }
            ToEngineMessage::ConnectionSuccess => {
                self.handle_worker_connection_success(msg.worker_number)?;
            }
            ToEngineMessage::Log(log) => {
                self.log_buffer.push_str(log.as_str());
            }
        }
        Ok(())
    }

    fn handle_stopped_message(&mut self, worker_num: u8) -> anyhow::Result<()> {
        let handle = unwrap_or_bail!(
            self.workers.get(&worker_num),
            "Worker #{} not found!",
            worker_num
        );
        let Some(tree) = self.byte_range_tree.as_ref() else {
            return Ok(());
        };
        let node = tree.search_node(&handle.range);
        if let Some(node) = node {
            // Only active ranges are marked as stopped. Complete ranges must stay complete.
            let mut node = node.borrow_mut();
            if node.status == ByteRangeStatus::Downloading {
                node.status = ByteRangeStatus::Stopped;
            }
            Ok(())
        } else {
            engine_warn!(self, "Failed to find node for worker #{}!", worker_num);
        }
    }

    async fn flush_logs(&mut self) -> anyhow::Result<()> {
        if self.log_buffer.is_empty() {
            return Ok(());
        }
        if !self.setting.logger_enabled {
            self.log_buffer.clear();
            return Ok(());
        }
        tokio::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(self.log_file_path())
            .await?
            .write_all(self.log_buffer.as_bytes())
            .await?;
        self.log_buffer.clear();

        Ok(())
    }

    fn handle_worker_connection_success(&mut self, worker_number: u8) -> anyhow::Result<()> {
        if let Some(worker) = self.workers.get_mut(&worker_number) {
            worker.awaiting_reset_response = false;
            worker.reset_count = 0;
            worker.failed = false;
            return Ok(());
        }

        anyhow::bail!(
            "handle_worker_connection_success:: Failed to find worker_num {} in list of workers",
            worker_number
        )
    }

    fn handle_worker_handshake(&mut self, worker_num: u8, reuse: bool) {
        self.pending_worker_handshakes.retain(|x| x != &worker_num);
        if reuse {
            let tree_ref = self.byte_range_tree.as_ref().unwrap();

            let reuse_request_nodes =
                tree_ref.lowest_level_nodes_by_status(ByteRangeStatus::ReuseRequested);

            let related_node = reuse_request_nodes
                .iter()
                .find(|x| x.borrow().worker_number == worker_num);

            if let Some(node) = related_node {
                node.borrow_mut().status = ByteRangeStatus::Downloading;
            }
        }
    }

    fn handle_range_download_completion(
        &mut self,
        worker_num: u8,
        range: ByteRange,
    ) -> anyhow::Result<()> {
        engine_log!(self, "Handling completion #{} {}", worker_num, range);
        if !self.reuse_worker_queue.contains(&worker_num) {
            engine_log!(self, "Pushed worker {} to reuse queue", worker_num);
            self.reuse_worker_queue.push_back(worker_num);
        }
        if let Some(handle) = self.workers.get_mut(&worker_num) {
            handle.reset_count = 0;
            handle.failed = false;
            handle.awaiting_reset_response = false;
        }
        let Some(tree_ref) = self.byte_range_tree.as_ref() else {
            return Ok(());
        };
        engine_log!(self, "Tree\n{}", tree_ref);
        let Some(node) = tree_ref.search_node(&range) else {
            engine_warn!(
                self,
                "handle_range_download_completion:: Failed to find node {} in tree for worker number {}",
                range,
                worker_num
            );
        };
        node.borrow_mut().status = ByteRangeStatus::Complete;
        let all_ranges_complete = tree_ref
            .lowest_level_nodes
            .iter()
            .all(|n| n.borrow().status == ByteRangeStatus::Complete);
        if all_ranges_complete {
            self.state = EngineState::WorkersComplete;
        }
        Ok(())
    }

    async fn handle_refresh_byte_range_overlap(
        &mut self,
        worker_num: u8,
        requested_range: ByteRange,
        refreshed_range: ByteRange,
        new_valid_range: ByteRange,
        reuse: bool,
    ) -> anyhow::Result<()> {
        engine_log!(
            self,
            "Handling overlap from worker {} with requested range {}",
            worker_num,
            requested_range
        );
        if self.byte_range_tree.is_none() {
            engine_warn!(
                self,
                "handle_refresh_byte_range_overlap:: Byte range tree is empty"
            )
        }

        let tree_ref = self.byte_range_tree.as_ref().unwrap();
        let Some(node) = tree_ref.search_node(&requested_range) else {
            engine_warn!(
                self,
                "handle_refresh_byte_range_overlap:: Failed to find segment node."
            );
        };

        self.update_worker_range(worker_num, refreshed_range.clone())?;

        let Some(parent_rc) = node.borrow().parent.upgrade() else {
            engine_warn!(self, "handle_refresh_byte_range_overlap:: Node has no parent");
        };
        let left_child_rc;
        let right_child_rc;
        let new_worker_number;
        let new_worker_node;

        {
            let mut parent = parent_rc.borrow_mut();

            left_child_rc = parent.left_child.as_ref().unwrap().clone();
            right_child_rc = parent.right_child.as_ref().unwrap().clone();

            {
                let mut left_child = left_child_rc.borrow_mut();
                left_child.range = refreshed_range.clone();
                left_child.status = ByteRangeStatus::Downloading;
            }

            {
                let mut right_child = right_child_rc.borrow_mut();
                right_child.status = ByteRangeStatus::ReuseRequested;
                right_child.range = new_valid_range.clone();
                new_worker_number = right_child.worker_number;
                new_worker_node = right_child_rc.clone();
            }

            parent.status = ByteRangeStatus::Outdated;
        }

        if reuse {
            self.send_start_command_reuse_worker(new_worker_number, new_valid_range.clone())
                .await?;
            new_worker_node.borrow_mut().status = ByteRangeStatus::Downloading;
        } else {
            self.spawn_worker(new_worker_number, right_child_rc).await?;
        }
        let _ = left_child_rc;
        engine_log!(
            self,
            "Tree after spawn for worker {}\n{}",
            worker_num,
            self.byte_range_tree.as_ref().unwrap()
        );

        Ok(())
    }

    async fn handle_refresh_byte_range_refused(
        &mut self,
        worker_number: u8,
        requested_range: ByteRange,
        reuse: bool,
    ) -> anyhow::Result<()> {
        engine_log!(
            self,
            "HandleRefreshByteRangeRefused coming from worker {}",
            worker_number
        );
        let Some(tree) = self.byte_range_tree.as_mut() else {
            return Ok(());
        };
        let Some(node) = tree.search_node(&requested_range) else {
            engine_warn!(
                self,
                "handle_refresh_byte_range_refused:: Failed to find segment node."
            )
        };
        let Some(parent_rc) = node.borrow().parent.upgrade() else {
            engine_warn!(self, "handle_refresh_byte_range_refused:: Node has no parent")
        };
        let (left_child, right_child) = {
            let parent = parent_rc.borrow();
            (parent.left_child.clone(), parent.right_child.clone())
        };
        if reuse {
            // The idle worker that was supposed to take over the right child goes back to queue
            if let Some(right) = &right_child {
                let reuse_worker = right.borrow().worker_number;
                if !self.reuse_worker_queue.contains(&reuse_worker) {
                    self.reuse_worker_queue.push_back(reuse_worker);
                }
            }
        } else {
            // Ranges are too small to be split further. Stop spawning new workers.
            self.spawned_workers = self.setting.total_connections;
        }

        // Restore the parent node as a lowest level node in place of its children
        let left_idx = left_child.as_ref().and_then(|l| {
            tree.lowest_level_nodes
                .iter()
                .position(|n| Rc::ptr_eq(n, l))
        });
        if let Some(idx) = left_idx {
            tree.lowest_level_nodes.insert(idx, parent_rc.clone());
            for child in [left_child.as_ref(), right_child.as_ref()].into_iter().flatten() {
                if let Some(pos) = tree
                    .lowest_level_nodes
                    .iter()
                    .position(|n| Rc::ptr_eq(n, child))
                {
                    tree.lowest_level_nodes.remove(pos);
                }
            }
        } else {
            engine_log!(
                self,
                "RefreshSegmentRefused:: Failed to find segment node to insert"
            );
        }
        {
            let mut parent = parent_rc.borrow_mut();
            // relink neighbors
            let left_neighbor = left_child
                .as_ref()
                .and_then(|l| l.borrow().left_neighbor.clone());
            let right_neighbor = right_child
                .as_ref()
                .and_then(|r| r.borrow().right_neighbor.clone());
            if let Some(ln) = &left_neighbor {
                ln.borrow_mut().right_neighbor = Some(parent_rc.clone());
            }
            if let Some(rn) = &right_neighbor {
                rn.borrow_mut().left_neighbor = Some(parent_rc.clone());
            }
            parent.left_neighbor = left_neighbor;
            parent.right_neighbor = right_neighbor;
            parent.remove_children();
            if parent.status != ByteRangeStatus::Complete {
                parent.status = ByteRangeStatus::Downloading;
            }
        }
        Ok(())
    }

    async fn handle_refresh_byte_range_success(
        &mut self,
        worker_num: u8,
        requested_range: ByteRange,
        reuse: bool,
    ) -> anyhow::Result<()> {
        if self.byte_range_tree.is_none() {
            return Ok(());
        }
        engine_log!(
            self,
            "Handling refresh success from worker {} with requested range {}",
            worker_num,
            requested_range
        );

        let node = {
            let tree = self.byte_range_tree.as_ref().unwrap();
            tree.search_node(&requested_range)
        };

        self.update_worker_range(worker_num, requested_range.clone())?;

        let Some(node) = node else {
            engine_warn!(
                self,
                "handle_refresh_byte_range_success:: Failed to find segment node"
            )
        };

        {
            let Some(parent_rc) = node.borrow().parent.upgrade() else {
                engine_warn!(self, "handle_refresh_byte_range_success:: Node has no parent")
            };
            let mut parent = parent_rc.borrow_mut();
            parent.status = ByteRangeStatus::Outdated;
            let worker_node = parent.right_child.as_ref().unwrap().clone();
            let mut worker_node_ref = parent.right_child.as_ref().unwrap().borrow_mut();
            if reuse {
                self.send_start_command_reuse_worker(
                    worker_node_ref.worker_number,
                    worker_node_ref.range.clone(),
                )
                .await?;
            } else {
                let node_worker_num = worker_node_ref.worker_number;
                drop(worker_node_ref);
                self.spawn_worker(node_worker_num, worker_node).await?;
                worker_node_ref = parent.right_child.as_ref().unwrap().borrow_mut();
            }
            parent.left_child.as_ref().unwrap().borrow_mut().status = ByteRangeStatus::Downloading;
            worker_node_ref.status = ByteRangeStatus::Downloading;
        }
        engine_log!(
            self,
            "Tree after spawn for worker {}\n{}",
            worker_num,
            self.byte_range_tree.as_ref().unwrap()
        );
        Ok(())
    }

    fn update_worker_range(&mut self, worker_num: u8, new_range: ByteRange) -> anyhow::Result<()> {
        if let Some(worker) = self.workers.get_mut(&worker_num) {
            worker.range = new_range;
            Ok(())
        } else {
            anyhow::bail!(
                "Failed to find worker {} updating refreshed range",
                worker_num
            )
        }
    }

    async fn send_start_command_reuse_worker(
        &mut self,
        worker_num: u8,
        range: ByteRange,
    ) -> anyhow::Result<()> {
        let paused = self.paused;
        if let Some(worker) = self.workers.get_mut(&worker_num) {
            worker.range = range.clone();
            worker.reset_count = 0;
            worker.failed = false;
            if let Result::Ok(mut p) = worker.progress_arc.lock() {
                p.last_response_time = now_millis();
            }
            worker
                .to_worker_tx
                .send(EngineToWorkerMsg::StartReuseWorker(range))
                .await?;
            if paused {
                worker.to_worker_tx.send(EngineToWorkerMsg::Stop).await?;
            }

            Ok(())
        } else {
            anyhow::bail!(
                "Failed to find worker {} when sending start command reuse worker",
                worker_num
            )
        }
    }

    /// Handles the start command for the download engine.
    ///
    /// On the initial start, it validates the integrity of temporary files to remove any corrupted files.
    /// It then builds the byte range tree based on missing byte ranges (those not yet downloaded).
    ///
    /// If the missing byte ranges are empty (i.e., this is a fresh download), the first download worker
    /// is spawned and assigned the entire byte range. Additional workers will be gradually spawned
    /// by `run_worker_spawner_ticker` if the file size justifies it.
    ///
    /// If the missing byte ranges are not empty (i.e., resuming a previous download), all allowed
    /// connections are created immediately.
    ///
    async fn handle_start(&mut self) -> anyhow::Result<()> {
        if self.byte_range_tree.is_none() {
            self.progress.status = Status::Connecting;
            engine_log!(self, "Inside start");
            self.prepopulate_worker_handles();
            if !self.download_item.supports_range {
                // Without range support every start begins from scratch with a single worker.
                self.clear_temp_dir();
            }
            self.validate_temp_files_integrity(false, true)?;
            let missing_ranges = self.find_missing_byte_ranges()?;
            for range in &missing_ranges {
                engine_log!(self, "Missing byte range:: {}", range);
            }
            if missing_ranges.is_empty() && self.is_assemble_eligible() {
                let _ = self.to_main_tx.try_send(EngineToMainMsg::Assembling);
                if !self.assemble_file()? {
                    anyhow::bail!("Failed to assemble the file");
                }
                return Ok(());
            }
            let max_workers = if self.download_item.supports_range {
                self.setting.total_connections
            } else {
                1
            };
            let tree = ByteRangeTree::from_missing_bytes(
                self.download_item.file_size,
                max_workers,
                missing_ranges,
            );
            engine_log!(self, "Tree result:\n{}", tree);
            // If the tree was built on top of existing temp files, the dynamic worker spawner
            // should not run because multiple ranges are already assigned to workers.
            if tree.lowest_level_nodes.len() != 1 || !self.download_item.supports_range {
                self.spawned_workers = self.setting.total_connections;
            }
            let nodes_to_spawn: Vec<NodeRef> = tree
                .lowest_level_nodes_by_status(ByteRangeStatus::ToDownload)
                .into_iter()
                .collect();
            self.byte_range_tree = Some(tree);
            for node in nodes_to_spawn {
                let worker_num = node.borrow().worker_number;
                self.spawn_worker(worker_num, node).await?;
            }
            self.calculate_base_downloaded_bytes()?;
        } else if self.paused {
            engine_log!(self, "Resuming download");
            self.paused = false;
            for node in &self.byte_range_tree.as_ref().unwrap().lowest_level_nodes {
                let mut node = node.borrow_mut();
                if node.status == ByteRangeStatus::Stopped {
                    node.status = ByteRangeStatus::Downloading;
                }
            }
            for handle in self.workers.values_mut() {
                handle.reset_count = 0;
                handle.failed = false;
                handle.awaiting_reset_response = false;
                if let Result::Ok(mut p) = handle.progress_arc.lock() {
                    p.last_response_time = now_millis();
                }
            }
            self.send_to_assigned_workers(EngineToWorkerMsg::Start)
                .await?;
            self.progress.status = Status::Connecting;
            let _ = self.to_main_tx.try_send(EngineToMainMsg::Resumed);
        }
        Ok(())
    }

    /// Sums up the sizes of the temp files that do not belong to any spawned worker. Workers only
    /// track the bytes of their own temp files, so without this, leftovers of a previous session
    /// downloaded by other worker numbers would not be reflected in the progress.
    fn calculate_base_downloaded_bytes(&mut self) -> anyhow::Result<()> {
        let dir = self.temp_dir();
        if !dir.exists() {
            self.base_downloaded_bytes = 0;
            return Ok(());
        }
        let assigned: Vec<u8> = self
            .workers
            .iter()
            .filter(|w| w.1.assigned_to_worker)
            .map(|w| *w.0)
            .collect();
        self.base_downloaded_bytes = list_temp_files_sorted(dir)?
            .iter()
            .filter(|f| !assigned.contains(&f.worker_number))
            .map(|f| f.size)
            .sum();
        Ok(())
    }

    fn temp_dir(&self) -> PathBuf {
        self.setting.base_temp_dir.join(&self.download_item.uid)
    }

    fn clear_temp_dir(&mut self) {
        let dir = self.temp_dir();
        if dir.exists() {
            if let Err(e) = fs::remove_dir_all(&dir) {
                engine_log!(self, "Failed to clear temp dir: {}", e);
            }
        }
    }

    /// Pre-assigns worker handles for a given number of workers before they are spawned.
    ///
    /// This allows sending messages to workers that have not yet spawned by the `worker_spawner_ticker`.
    /// For example, if a pause command arrives just before a worker is spawned, the message can
    /// still be queued on the appropriate channel and will be received as soon as the worker starts.
    fn prepopulate_worker_handles(&mut self) {
        for worker_num in 0..self.setting.total_connections {
            engine_log!(self, "Prepopulating worker #{}", worker_num);
            let (to_worker_tx, from_engine_rx) =
                tokio::sync::mpsc::channel::<EngineToWorkerMsg>(100);
            let progress = Arc::new(Mutex::new(WorkerProgress::new()));
            let worker_handle = DownloadWorkerHandle {
                assigned_to_worker: false,
                range: ByteRange::empty(),
                to_worker_tx: to_worker_tx.clone(),
                engine_to_worker_rx: Some(from_engine_rx),
                progress_arc: progress.clone(),
                awaiting_reset_response: false,
                reset_count: 0,
                failed: false,
                join_handle: None,
            };
            self.workers.insert(worker_num, worker_handle);
        }
    }

    async fn spawn_worker(&mut self, worker_num: u8, tree_node: NodeRef) -> anyhow::Result<()> {
        let handle = unwrap_or_bail!(
            self.workers.get_mut(&worker_num),
            "Failed to spawn worker #{}. Handle not found",
            worker_num
        );

        let engine_to_worker_rx = unwrap_or_bail!(
            handle.engine_to_worker_rx.take(),
            "Failed to spawn worker #{}. receiver not found",
            worker_num
        );

        let range = {
            let mut node = tree_node.borrow_mut();
            node.status = ByteRangeStatus::Downloading;
            node.range.clone()
        };

        let mut worker = HttpDownloadWorker::new(
            worker_num,
            self.setting.clone(),
            self.download_item.clone(),
            range.clone(),
            self.from_worker_tx.clone(),
            engine_to_worker_rx,
            handle.progress_arc.clone(),
            self.rate_limiter.clone(),
        );

        handle.range = range;
        handle.assigned_to_worker = true;
        if self.paused {
            // queued before the worker starts, so it stops right away
            handle.to_worker_tx.send(EngineToWorkerMsg::Stop).await?;
        }
        handle.join_handle = Some(
            thread::Builder::new()
                .name(format!("kasma-worker-{}", worker_num))
                .spawn(move || worker.run())?,
        );

        self.spawned_workers = self.spawned_workers.saturating_add(1);
        if !self.pending_worker_handshakes.contains(&worker_num) {
            self.pending_worker_handshakes.push(worker_num);
        }
        engine_log!(self, "Spawned worker #{}", worker_num);
        Ok(())
    }

    async fn send_to_assigned_workers(&self, msg: EngineToWorkerMsg) -> anyhow::Result<()> {
        for handle in self.workers.iter().filter(|w| w.1.assigned_to_worker) {
            let sender = &handle.1.to_worker_tx;
            sender.send(msg.clone()).await?;
        }
        Ok(())
    }

    /// Checks the temp files' integrity and optionally deletes corrupted files by checking for
    /// missing ranges (optional), clashing ranges between different temp files, inconsistent temp
    /// file range with the temp file's actual size, and ranges exceeding the content length.
    ///
    /// Returns whether corrupted temp files were found.
    fn validate_temp_files_integrity(
        &mut self,
        check_missing_range: bool,
        delete_corrupted: bool,
    ) -> anyhow::Result<bool> {
        let dir = self.temp_dir();
        if !dir.exists() {
            return Ok(false);
        }
        let temp_files = list_temp_files_sorted(dir)?;
        if temp_files.is_empty() {
            return Ok(false);
        }
        let final_end = self.download_item.file_size.saturating_sub(1);
        // keyed by path to prevent deleting the same file twice
        let mut files_to_delete: HashMap<PathBuf, &TempFileMetadata> = HashMap::new();
        for idx in 0..temp_files.len() {
            let curr_file = &temp_files[idx];
            if curr_file.end_byte < curr_file.start_byte
                || curr_file.end_byte - curr_file.start_byte + 1 != curr_file.size
            {
                engine_log!(
                    self,
                    "Found bad length :: {} :: size {}",
                    curr_file.name,
                    curr_file.size
                );
                files_to_delete.insert(curr_file.path.clone(), curr_file);
            }
            if self.download_item.file_size == 0
                || curr_file.start_byte > final_end
                || curr_file.end_byte > final_end
            {
                engine_log!(
                    self,
                    "Found byte range exceeding content length :: {}",
                    curr_file.name
                );
                files_to_delete.insert(curr_file.path.clone(), curr_file);
            }
            if idx == temp_files.len() - 1 {
                continue;
            }
            let next_file = &temp_files[idx + 1];
            // Cases where there is a single missing byte
            if next_file.start_byte > curr_file.end_byte
                && next_file.start_byte - curr_file.end_byte == 2
            {
                files_to_delete.insert(curr_file.path.clone(), curr_file);
                let neighbor = if idx == 0 {
                    next_file
                } else {
                    &temp_files[idx - 1]
                };
                files_to_delete.insert(neighbor.path.clone(), neighbor);
            }
            if check_missing_range && next_file.start_byte != curr_file.end_byte + 1 {
                engine_log!(
                    self,
                    "Found inconsistent temp files :: {} == {}",
                    curr_file.name,
                    next_file.name
                );
                files_to_delete.insert(curr_file.path.clone(), curr_file);
                files_to_delete.insert(next_file.path.clone(), next_file);
            }
            let curr_range = ByteRange::new(curr_file.start_byte, curr_file.end_byte);
            for other_file in &temp_files[idx + 1..] {
                if other_file.start_byte > curr_file.end_byte {
                    break;
                }
                let other_range = ByteRange::new(other_file.start_byte, other_file.end_byte);
                if curr_range.overlaps(&other_range) {
                    engine_log!(
                        self,
                        "Found overlapping temp files: {} === {}",
                        curr_file.name,
                        other_file.name
                    );
                    files_to_delete.insert(curr_file.path.clone(), curr_file);
                    files_to_delete.insert(other_file.path.clone(), other_file);
                }
            }
        }
        if files_to_delete.is_empty() {
            return Ok(false);
        }
        engine_log!(self, "==== Total bad temp files: {} ====", files_to_delete.len());
        if delete_corrupted {
            for (path, file) in files_to_delete {
                engine_log!(self, "Deleting bad temp file {}", file.name);
                match fs::remove_file(&path) {
                    Result::Ok(_) => {}
                    Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
                        engine_log!(self, "Bad temp file {} was already deleted", file.name);
                    }
                    Err(e) => {
                        anyhow::bail!("Failed to delete bad temp file {}: {}", file.name, e);
                    }
                }
            }
        }
        Ok(true)
    }

    /// Analyzes the temp files and returns the missing byte ranges.
    ///
    /// `file_size` is a byte count while temp file end bytes are inclusive byte indexes.
    /// Therefore, the last valid byte is always `file_size - 1`.
    fn find_missing_byte_ranges(&self) -> anyhow::Result<Vec<ByteRange>> {
        if self.download_item.file_size == 0 {
            return Ok(vec![]);
        }
        let final_end = self.download_item.file_size - 1;
        let temp_dir_path = self.temp_dir();
        let mut temp_files: Vec<TempFileMetadata> = vec![];
        if temp_dir_path.is_dir() {
            temp_files = list_temp_files_sorted(temp_dir_path)?;
        }
        if temp_files.is_empty() {
            return Ok(vec![ByteRange::new(0, final_end)]);
        }

        let mut missing_ranges: Vec<ByteRange> = vec![];
        let mut next_expected_start: u64 = 0;
        for file in &temp_files {
            if file.start_byte > next_expected_start {
                missing_ranges.push(ByteRange::new(
                    next_expected_start,
                    (file.start_byte - 1).min(final_end),
                ));
            }
            if file.end_byte >= next_expected_start {
                next_expected_start = file.end_byte + 1;
            }
            if next_expected_start > final_end {
                break;
            }
        }
        if next_expected_start <= final_end {
            missing_ranges.push(ByteRange::new(next_expected_start, final_end));
        }

        missing_ranges.retain(|r| r.start <= final_end);
        missing_ranges.sort_by(|a, b| a.start.cmp(&b.start));
        Ok(missing_ranges)
    }

    fn is_assemble_eligible(&self) -> bool {
        !self.assemble_requested
    }

    fn output_file_path(&self) -> PathBuf {
        self.progress
            .output_path
            .clone()
            .unwrap_or_else(|| self.setting.base_save_dir.join(&self.download_item.file_name))
    }

    /// Writes all temp files into the final file using a fixed size buffer, verifies the size
    /// of the written file and deletes the temp directory on success.
    fn assemble_file(&mut self) -> anyhow::Result<bool> {
        self.assemble_requested = true;
        engine_log!(self, "Assembling file...");
        let temp_files = list_temp_files_sorted(self.temp_dir())?;
        let mut file_to_write = self.setting.base_save_dir.join(&self.download_item.file_name);
        if file_to_write.exists() {
            file_to_write = resolve_versioned_file_path(
                self.download_item.file_name.clone(),
                &self.setting.base_save_dir,
            )?;
        }
        let mut output = match OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(&file_to_write)
        {
            Result::Ok(f) => f,
            Err(e) => {
                engine_log!(
                    self,
                    "Failed to create {}: {}. Falling back to uid",
                    file_to_write.display(),
                    e
                );
                file_to_write = resolve_versioned_file_path(
                    self.download_item.uid.clone(),
                    &self.setting.base_save_dir,
                )?;
                OpenOptions::new()
                    .write(true)
                    .create(true)
                    .truncate(true)
                    .open(&file_to_write)?
            }
        };

        let mut buffer = vec![0u8; ASSEMBLE_BUFFER_SIZE];
        let mut assembled_bytes: u64 = 0;
        let write_result: anyhow::Result<()> = (|| {
            for temp_file in &temp_files {
                let mut input = File::open(&temp_file.path)?;
                loop {
                    let read = input.read(&mut buffer)?;
                    if read == 0 {
                        break;
                    }
                    output.write_all(&buffer[..read])?;
                    assembled_bytes += read as u64;
                }
            }
            output.flush()?;
            Ok(())
        })();
        drop(output);

        let written_len = fs::metadata(&file_to_write).map(|m| m.len()).unwrap_or(0);
        let success = write_result.is_ok()
            && assembled_bytes == self.download_item.file_size
            && written_len == self.download_item.file_size;
        if success {
            engine_log!(self, "File assembled successfully: {}", file_to_write.display());
            self.progress.output_path = Some(file_to_write);
            self.state = EngineState::Complete;
            self.clear_temp_dir();
        } else {
            engine_log!(
                self,
                "Assemble failed! error: {:?} written: {} expected: {}",
                write_result.err(),
                written_len,
                self.download_item.file_size
            );
            let _ = fs::remove_file(&file_to_write);
            self.assemble_requested = false;
        }
        Ok(success)
    }

    fn log_file_path(&mut self) -> PathBuf {
        let log_file_name = format!("{}_log.txt", self.download_item.uid);
        PathBuf::from(self.setting.base_temp_dir.clone())
            .join("logs")
            .join(log_file_name)
    }
}

/// Bytes the worker has received for `range`. 0 if the worker's progress belongs to another range
/// (the engine assigned `range` but the worker has not started it yet).
fn range_bytes_for(progress: &WorkerProgress, range: &ByteRange) -> u64 {
    if progress.range_start == Some(range.start) {
        progress.range_bytes_received.min(range.len())
    } else {
        0
    }
}

/// Calculates the exponential backoff delay for the given retry count, capped at
/// [`MAX_RETRY_BACKOFF_MILLIS`] (or `base_millis` if it is larger).
fn backoff_delay_millis(retry_count: u32, base_millis: u64) -> u64 {
    if retry_count == 0 {
        return base_millis;
    }
    let factor = 1u64 << retry_count.min(16);
    base_millis
        .saturating_mul(factor)
        .min(MAX_RETRY_BACKOFF_MILLIS.max(base_millis))
}

/// Builds a deterministic uid from the url and the file size, so that the same download started
/// again in a later session finds its temp files and resumes.
pub fn download_uid(url: &str, file_size: u64) -> String {
    // FNV-1a (64 bit). Stable across Rust versions, unlike DefaultHasher.
    let mut hash: u64 = 0xcbf29ce484222325;
    for byte in url.as_bytes().iter().chain(file_size.to_le_bytes().iter()) {
        hash ^= *byte as u64;
        hash = hash.wrapping_mul(0x100000001b3);
    }
    format!("{:016x}", hash)
}
