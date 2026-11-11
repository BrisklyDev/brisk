use crate::download_engine::http::byte_range::ByteRange;
use crate::download_engine::http::http_download_worker::Status;
use std::path::PathBuf;

pub enum DownloadCommand {
    Pause,
    Start,
    /// Stops all workers (flushing their buffers to disk) and terminates the engine.
    /// The download can be resumed later by starting a new engine for the same download.
    Terminate,
}

pub struct ButtonAvailability {
    pub pause_available: bool,
    pub resume_available: bool,
}

#[derive(Debug, Clone)]
pub enum EngineToWorkerMsg {
    Start,
    Stop,
    Reset,
    // args: new byte range, reuse
    RefreshByteRange(ByteRange, bool),
    StartReuseWorker(ByteRange),
    /// Exits the worker's event loop and ends its thread.
    Terminate,
}

/// A snapshot of the overall download progress sent to the main thread.
#[derive(Debug, Clone)]
pub struct ProgressReport {
    /// Overall progress in the range of 0.0..=1.0
    pub progress: f64,
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
    pub speed_bytes_per_sec: u64,
    pub estimated_remaining_sec: u64,
    pub estimated_remaining: String,
    pub status: Status,
    pub active_workers: usize,
    pub workers: Vec<WorkerReport>,
    /// How the file is currently split between workers, ordered by start byte. Ranges that are
    /// not part of the byte range tree (downloaded in a previous session) are reported as
    /// complete segments. Empty if the download does not support ranges.
    pub segments: Vec<SegmentReport>,
}

#[derive(Debug, Clone)]
pub struct WorkerReport {
    pub worker_number: u8,
    pub status: Status,
    pub speed_bytes_per_sec: u64,
    /// Inclusive byte range currently assigned to the worker
    pub range_start: u64,
    pub range_end: u64,
    /// Bytes received for the current range, counted from `range_start`
    pub range_received_bytes: u64,
}

#[derive(Debug, Clone)]
pub struct SegmentReport {
    pub start: u64,
    /// Inclusive end byte
    pub end: u64,
    pub worker_number: u8,
    /// Bytes received for this segment, counted from `start`
    pub received_bytes: u64,
    pub complete: bool,
    pub active: bool,
}

pub enum EngineToMainMsg {
    Uid(String),
    /// Sent once the file information has been fetched and the download is about to start.
    Info {
        file_name: String,
        file_size: u64,
        supports_range: bool,
    },
    Progress(ProgressReport),
    Paused,
    Resumed,
    /// The temp files are being assembled into the final file
    Assembling,
    /// The download has been completed and the file has been written to the given path.
    Complete(PathBuf),
    /// The download has failed and the engine has terminated.
    Failed(String),
    /// All connections exceeded the maximum retry count. The engine has terminated.
    NetworkError(String),
    /// The engine was terminated by a [`DownloadCommand::Terminate`] command.
    Terminated,
}

#[derive(Debug)]
pub struct WorkerToEngineMsg {
    pub(crate) worker_number: u8,
    pub(crate) message: ToEngineMessage,
}

#[derive(Debug)]
pub enum ToEngineMessage {
    ConnectionSuccess,
    Complete(ByteRange),
    HandshakeResponse {
        reuse: bool,
    },
    ByteRangeRefreshSuccess {
        requested_range: ByteRange,
        reuse: bool,
    },
    ByteRangeRefreshRefused {
        requested_range: ByteRange,
        reuse: bool,
    },
    ByteRangeRefreshOverlapped {
        requested_range: ByteRange,
        refreshed_range: ByteRange,
        new_valid_range: ByteRange,
        reuse: bool,
    },
    Log(String),
    Stopped,
    Failed,
}
