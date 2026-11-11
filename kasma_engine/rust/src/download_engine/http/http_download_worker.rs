use crate::download_engine::errors::DownloadError;
use crate::download_engine::http::byte_range::{self, ByteRange};
use crate::download_engine::http::rate_limiter::SharedRateLimiter;
use crate::download_engine::http::http_download_engine::{
    MINIMUM_DOWNLOADABLE_BYTE_RANGE_LEN, WORKER_REUSE_TICKER_SECS,
};
use crate::download_engine::http::http_download_worker::Status::RangeComplete;
use crate::download_engine::http::message::EngineToWorkerMsg::RefreshByteRange;
use crate::download_engine::http::message::{
    EngineToWorkerMsg, ToEngineMessage, WorkerToEngineMsg,
};
use crate::download_engine::http::progress::WorkerProgress;
use crate::download_engine::http::{ClientError, HttpClient};
use crate::download_engine::setting::DownloadSetting;
use crate::download_engine::utils::file::{TempFileMetadata, list_files_in_dir};
use crate::download_engine::utils::now_millis;
use crate::download_engine::utils::sync_ext::MutexAnyhowExt;
use crate::download_engine::{DownloadItem, RunnableTask};
use crate::worker_log;
use http_body_util::{BodyExt, Empty};
use hyper::body::{Bytes, Frame};
use hyper::{Request, http};
use std::fs::{File, create_dir_all, remove_file};
use std::io::Read;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use std::vec;
use tokio::sync::mpsc::{Receiver, Sender};
use tokio::time::interval;

const SPEED_CHECK_WINDOW_MILLIS: u32 = 1100;
const MIN_FLUSH: u64 = 64 * 1024; // 64 KB
const MAX_FLUSH: u64 = 8 * 1024 * 1024; // 8 MB

const LOG_BUFFER_SEND_TICKER_SECS: u64 = 1;

pub const USER_AGENT: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

/// The worker is responsible for downloading a file using HTTP. Workers are spawned in their own
/// threads by the engine, and a single-threaded tokio runtime is spawned on their threads.
/// Workers communicate with the engine via the `to_engine_tx` and `from_engine_rx` to send and
/// receive messages respectively.
pub struct HttpDownloadWorker {
    worker_number: u8,
    client: HttpClient,
    setting: DownloadSetting,
    status_downloading: bool,
    download_info: DownloadItem,
    byte_range: ByteRange,
    data_buffer: Vec<Bytes>,
    log_buffer: String,
    speed_check_bytes: u64,
    to_engine_tx: Sender<WorkerToEngineMsg>,
    from_engine_rx: Receiver<EngineToWorkerMsg>,
    progress: Arc<Mutex<WorkerProgress>>,
    last_speed_check_epoch_millis: u128,
    temp_bytes_received: u64,
    buffer_flush_threshold: u64,
    prev_buffer_end_byte: u64,
    total_request_bytes_received: u64,
    total_bytes_received: u64,
    cached_temp_files: Vec<TempFileMetadata>,
    terminated_on_completion: bool,
    rate_limiter: Option<SharedRateLimiter>,
}

impl HttpDownloadWorker {
    pub fn new(
        worker_number: u8,
        setting: DownloadSetting,
        info: DownloadItem,
        byte_range: ByteRange,
        to_engine_tx: Sender<WorkerToEngineMsg>,
        from_engine_rx: Receiver<EngineToWorkerMsg>,
        progress: Arc<Mutex<WorkerProgress>>,
        rate_limiter: Option<SharedRateLimiter>,
    ) -> Self {
        HttpDownloadWorker {
            download_info: info,
            client: HttpClient::new(),
            status_downloading: false,
            worker_number,
            byte_range,
            data_buffer: vec![],
            log_buffer: String::new(),
            speed_check_bytes: 0,
            to_engine_tx,
            from_engine_rx,
            progress,
            last_speed_check_epoch_millis: now_millis(),
            temp_bytes_received: 0,
            buffer_flush_threshold: 0,
            prev_buffer_end_byte: 0,
            total_request_bytes_received: 0,
            total_bytes_received: 0,
            cached_temp_files: vec![],
            terminated_on_completion: false,
            rate_limiter,
            setting,
        }
    }
}

impl RunnableTask for HttpDownloadWorker {
    fn run(&mut self) {
        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .unwrap()
            .block_on(self.run_async());
    }
}

impl HttpDownloadWorker {
    async fn run_async(&mut self) {
        let handshake = ToEngineMessage::HandshakeResponse { reuse: false };
        self.send_to_engine(handshake).await;
        if self.start_download(false, false).await {
            self.run_event_loop().await;
        }
        self.send_log_buffer_to_engine().await;
    }

    async fn run_event_loop(&mut self) {
        loop {
            self.send_log_buffer_to_engine().await;

            match self.from_engine_rx.recv().await {
                Some(EngineToWorkerMsg::Start) => {
                    if !self.start_download(false, false).await {
                        break;
                    }
                }
                Some(EngineToWorkerMsg::Stop) => {
                    worker_log!(self, "Cancel received");
                    self.progress.lock().unwrap().status = Status::Stopped;
                }
                Some(EngineToWorkerMsg::RefreshByteRange(range, reuse)) => {
                    self.handle_refresh_byte_range_message(range.clone(), reuse)
                        .await;
                    worker_log!(
                        self,
                        "received refresh byte range in event loop with range {}",
                        range
                    );
                }
                Some(EngineToWorkerMsg::Reset) => {
                    worker_log!(self, "Reset received in event loop");
                    if !self.start_download(false, true).await {
                        break;
                    }
                }
                Some(EngineToWorkerMsg::StartReuseWorker(range)) => {
                    worker_log!(self, "StartReuseWorker received in event loop");
                    self.byte_range = range;
                    if !self.start_download(true, false).await {
                        break;
                    }
                }
                Some(EngineToWorkerMsg::Terminate) | None => {
                    // The engine has requested termination or dropped the sender.
                    worker_log!(self, "Terminating worker");
                    break;
                }
            }
        }
    }

    /// Starts the download and reports the result to the engine.
    /// Returns false if the worker has been asked to terminate.
    async fn start_download(&mut self, mut reuse: bool, mut reset: bool) -> bool {
        loop {
            match self.start_download_inner(reuse, reset).await {
                Ok(Status::RangeComplete) => {
                    self.send_to_engine(ToEngineMessage::Complete(self.byte_range.clone()))
                        .await;
                }
                Ok(Status::Stopped) => self.send_to_engine(ToEngineMessage::Stopped).await,
                // The connection was interrupted by a reset or a refreshed byte range before
                // the response arrived. Restart the connection immediately.
                Ok(Status::Resetting) => {
                    reset = true;
                    reuse = false;
                    continue;
                }
                Ok(Status::Starting) => {
                    // Interrupted by a StartReuseWorker command. byte_range is already updated.
                    reset = false;
                    reuse = true;
                    continue;
                }
                Ok(Status::Complete) => return false, // termination requested
                Ok(_) => {}
                Err(DownloadError::InvalidCommand) => {}
                Err(e) => {
                    worker_log!(self, "Download failed: {}", e);
                    {
                        let mut progress = self.progress.lock().unwrap();
                        progress.speed_bytes_per_sec = 0;
                        if progress.status == Status::Downloading {
                            progress.status = Status::Failed;
                        }
                    }
                    self.status_downloading = false;
                    self.send_to_engine(ToEngineMessage::Failed).await
                }
            }
            return true;
        }
    }

    /// Handles a message received from the engine while a download request is in progress.
    /// Returns `Some(status)` when the current request must be abandoned.
    async fn handle_engine_msg_during_download(
        &mut self,
        msg: Option<EngineToWorkerMsg>,
        before_response: bool,
    ) -> Option<Status> {
        match msg {
            Some(EngineToWorkerMsg::Stop) => {
                self.handle_stop_message();
                Some(Status::Stopped)
            }
            Some(RefreshByteRange(new_range, reuse)) => {
                worker_log!(self, "Refreshed byte range during download");
                self.handle_refresh_byte_range_message(new_range, reuse)
                    .await;
                if before_response {
                    // the request has not been answered yet. Restart with the new range.
                    self.set_reset_status();
                    Some(Status::Resetting)
                } else {
                    None
                }
            }
            Some(EngineToWorkerMsg::Reset) => {
                self.set_reset_status();
                Some(Status::Resetting)
            }
            Some(EngineToWorkerMsg::Start) => {
                // Already running. Nothing to do.
                None
            }
            Some(EngineToWorkerMsg::StartReuseWorker(range)) => {
                worker_log!(self, "StartReuseWorker received during download");
                let _ = self.flush_buffer();
                self.byte_range = range;
                Some(Status::Starting)
            }
            Some(EngineToWorkerMsg::Terminate) | None => {
                worker_log!(self, "Terminate received during download");
                let _ = self.flush_buffer();
                self.progress.lock().unwrap().status = Status::Stopped;
                Some(Status::Complete)
            }
        }
    }

    /// Starts the download process.
    ///
    /// The worker is initialized with proper values, and then a `tokio::select!` runs with two branches:
    ///
    /// - `self.from_engine_rx.recv()`: listens to messages coming from the engine.
    /// - `response = client.send(req)`: sends the HTTP request via hyper.
    ///
    /// The purpose of this initial `tokio::select!` is to handle scenarios such as:
    /// the request is sent but takes time due to network or server issues. While waiting,
    /// if a reset or pause command is received from the engine, it is processed immediately
    /// because the select is biased toward listening to engine messages first, allowing
    /// the download to terminate instantaneously without waiting for the network.
    ///
    /// If the request completes successfully without interruption, an infinite loop over another
    /// `tokio::select!` is run. This loop also listens to `self.from_engine_rx.recv()` for engine
    /// messages, while simultaneously processing the incoming data chunks from the network.
    ///
    /// The `reuse` parameter indicates whether this start is for connection reuse:
    /// when a worker finishes downloading and is assigned a new byte range.
    ///
    async fn start_download_inner(
        &mut self,
        reuse: bool,
        reset: bool,
    ) -> Result<Status, DownloadError> {
        worker_log!(self, "Starting download with range {}", self.byte_range);
        if self.check_start_not_allowed(reuse, reset) {
            worker_log!(self, "start not allowed!");
            return Err(DownloadError::InvalidCommand);
        }
        if let Err(e) = self.init().await {
            worker_log!(self, "Failed to initialize download: {}", e);
            self.progress.lock().unwrap().status = Status::Failed;
            return Err(DownloadError::Other(e.to_string()));
        }
        if reset {
            worker_log!(self, "Resetting worker with range {}", self.byte_range);
            self.reset_status();
        }
        if !self.download_info.supports_range {
            // The server does not support range requests. Every request starts from byte 0.
            self.clear_own_temp_files();
        } else if !reuse && self.is_range_download_complete() {
            worker_log!(self, "Range {} already fully on disk", self.byte_range);
            self.set_download_complete();
            return Ok(RangeComplete);
        }

        let mut log_ticker = interval(Duration::from_secs(LOG_BUFFER_SEND_TICKER_SECS));
        let req = self.build_request(reuse)?;
        let requested_partial = self.download_info.supports_range;
        let response = tokio::select! {
            biased;

            msg = self.from_engine_rx.recv() => {
                if let Some(status) = self.handle_engine_msg_during_download(msg, true).await {
                    return Ok(status);
                }
                // Messages that don't interrupt the request (e.g. Start) restart the request
                self.set_reset_status();
                return Ok(Status::Resetting);
            },

            response = self.client.send(req) => response,
        };

        let resp = match response {
            Ok(resp) => resp,
            Err(e) => {
                worker_log!(self, "Download error {}", e);
                return Err(DownloadError::Transport(e.to_string()));
            }
        };
        if requested_partial && resp.status() != hyper::StatusCode::PARTIAL_CONTENT {
            worker_log!(
                self,
                "Server responded with {} instead of 206 for a range request",
                resp.status()
            );
            return Err(DownloadError::Other(format!(
                "Unexpected status code {} for range request",
                resp.status()
            )));
        }

        let mut body = resp.into_body();
        let mut rate_sleep = Duration::ZERO;

        loop {
            // Apply rate-limiter backpressure BEFORE reading the next frame.
            // Sleeping here (not inside process_chunk) ensures we don't ask
            // hyper for more data while we're waiting, so the TCP receive
            // window fills up and the server actually slows down.
            if !rate_sleep.is_zero() {
                tokio::select! {
                    biased;
                    msg = self.from_engine_rx.recv() => {
                        if let Some(status) = self.handle_engine_msg_during_download(msg, false).await {
                            return Ok(status);
                        }
                        // Engine message interrupted the sleep; reset sleep so
                        // the rate limiter recomputes on next consume call.
                        rate_sleep = Duration::ZERO;
                        continue;
                    }
                    _ = tokio::time::sleep(rate_sleep) => {
                        rate_sleep = Duration::ZERO;
                    }
                }
            }

            tokio::select! {
                biased;

                msg = self.from_engine_rx.recv() => {
                    if let Some(status) = self.handle_engine_msg_during_download(msg, false).await {
                        return Ok(status);
                    }
                },

                frame = body.frame() => {
                    match frame {
                        Some(Ok(chunk)) => {
                            match self.process_chunk(chunk).await {
                                Ok((true, _)) => return Ok(RangeComplete),
                                Ok((false, wait)) => rate_sleep = wait,
                                Err(e) => {
                                    worker_log!(self, "Process chunk error {}", e);
                                    return Err(DownloadError::ProcessChunk);
                                }
                            }
                        }
                        Some(Err(e)) => {
                            let _ = self.flush_buffer();
                            return Err(DownloadError::Other(e.to_string()));
                        }
                        None => {
                            worker_log!(self, "Response body ended");
                            return self.handle_download_complete();
                        }
                    }
                },

                _ = log_ticker.tick() => {
                    self.send_log_buffer_to_engine().await;
                }
            }
        }
    }

    async fn send_log_buffer_to_engine(&mut self) {
        if self.log_buffer.is_empty() {
            return;
        }
        self.send_to_engine(ToEngineMessage::Log(self.log_buffer.clone()))
            .await;
        self.log_buffer.clear();
    }

    /// Called when the response body has ended. If the server closed the connection before the
    /// whole range was received, the received bytes are kept and an error is returned so the
    /// engine can reset the connection and continue from where it left off.
    fn handle_download_complete(&mut self) -> Result<Status, DownloadError> {
        if self.flush_buffer().is_err() {
            return Err(DownloadError::ProcessChunk);
        }
        let expected = if self.download_info.supports_range {
            self.byte_range.len()
        } else {
            self.download_info.file_size
        };
        if self.total_request_bytes_received < expected {
            worker_log!(
                self,
                "Response ended prematurely: received {} of {} bytes",
                self.total_request_bytes_received,
                expected
            );
            return Err(DownloadError::Other("Response ended prematurely".into()));
        }
        worker_log!(self, "Download finished.");
        self.set_download_complete();
        Ok(RangeComplete)
    }

    fn handle_stop_message(&mut self) {
        worker_log!(
            self,
            "Cancel message received from engine. Exiting download..."
        );
        let _ = self.flush_buffer();
        let mut progress = self.progress.lock().unwrap();
        progress.status = Status::Stopped;
        progress.speed_bytes_per_sec = 0;
        drop(progress);
        self.status_downloading = false;
    }

    async fn handle_refresh_byte_range_message(&mut self, new_range: ByteRange, reuse: bool) {
        let result = self.refresh_byte_range(new_range, reuse);
        self.send_to_engine(result).await;
    }

    fn set_reset_status(&mut self) {
        worker_log!(
            self,
            "Reset message received from engine. Exiting download..."
        );
        self.progress.lock().unwrap().status = Status::Resetting;
        self.status_downloading = false;
    }

    fn check_start_not_allowed(&mut self, reuse: bool, reset: bool) -> bool {
        // Byte ranges are inclusive, therefore the last valid byte is file_size - 1
        if self.byte_range.start > self.byte_range.end
            || self.byte_range.start >= self.download_info.file_size
            || self.byte_range.end >= self.download_info.file_size
        {
            worker_log!(
                self,
                "Invalid byte range: {}-{}. Skipping...",
                self.byte_range.start,
                self.byte_range.end
            );
            return true;
        }
        if reuse || reset {
            return false;
        }
        let status = self.progress.lock().unwrap().status;
        matches!(status, Status::Downloading | Status::Connecting)
    }

    /// Checks whether the temp files of this worker fully cover its assigned byte range.
    fn is_range_download_complete(&mut self) -> bool {
        let files = self.temp_files_sorted(true);
        let (Some(first), Some(last)) = (files.first(), files.last()) else {
            return false;
        };
        if first.start_byte > self.byte_range.start || last.end_byte < self.byte_range.end {
            return false;
        }
        let mut next_expected = self.byte_range.start;
        for file in &files {
            if file.start_byte > next_expected {
                worker_log!(self, "Found gap before temp file {}", file.name);
                return false;
            }
            next_expected = next_expected.max(file.end_byte + 1);
        }
        next_expected > self.byte_range.end
    }

    /// Deletes all the temp files of this worker. Used for servers that don't support range
    /// requests, where every new request starts from the beginning of the file.
    fn clear_own_temp_files(&mut self) {
        for file in self.cached_temp_files.drain(..) {
            let _ = remove_file(&file.path);
        }
        self.total_bytes_received = 0;
        self.total_request_bytes_received = 0;
        self.prev_buffer_end_byte = 0;
    }

    async fn init(&mut self) -> anyhow::Result<()> {
        {
            self.progress.lock_anyhow()?.status = Status::Connecting;
        }
        self.terminated_on_completion = false;
        self.total_request_bytes_received = 0;
        self.status_downloading = false;
        create_dir_all(self.temp_directory())?;
        self.init_temp_files_cache();
        Ok(())
    }

    async fn send_to_engine(&mut self, message: ToEngineMessage) {
        let msg = WorkerToEngineMsg {
            worker_number: self.worker_number,
            message,
        };
        if let Err(e) = self.to_engine_tx.send(msg).await {
            worker_log!(self, "Failed to send message to engine: {}", e);
        }
    }

    fn refresh_byte_range(&mut self, new_range: ByteRange, reuse_worker: bool) -> ToEngineMessage {
        let prev_end_byte = self.byte_range.end;
        if self.progress.lock().unwrap().status == RangeComplete {
            return ToEngineMessage::ByteRangeRefreshRefused {
                requested_range: new_range,
                reuse: reuse_worker,
            };
        }
        if self.byte_range.end <= self.byte_range.start + self.total_request_bytes_received {
            return ToEngineMessage::ByteRangeRefreshRefused {
                requested_range: new_range,
                reuse: reuse_worker,
            };
        }
        if self.byte_range.start + self.total_request_bytes_received >= new_range.end {
            let received_end = self.byte_range.start + self.total_request_bytes_received;
            let split_byte = (self.byte_range.end - received_end) / 2;
            let new_end = split_byte + received_end;
            // The length of the range that will be handed to the other worker
            let new_valid_len = prev_end_byte.saturating_sub(new_end);

            return if split_byte > 0
                && new_range.start < new_end
                && new_valid_len > MINIMUM_DOWNLOADABLE_BYTE_RANGE_LEN
            {
                self.byte_range = ByteRange::new(new_range.start, new_end);
                worker_log!(
                    self,
                    "#{} Byte range refreshed {}",
                    self.worker_number,
                    self.byte_range
                );
                ToEngineMessage::ByteRangeRefreshOverlapped {
                    requested_range: new_range.clone(),
                    new_valid_range: ByteRange::new(self.byte_range.end + 1, prev_end_byte),
                    refreshed_range: self.byte_range.clone(),
                    reuse: reuse_worker,
                }
            } else {
                ToEngineMessage::ByteRangeRefreshRefused {
                    requested_range: new_range,
                    reuse: reuse_worker,
                }
            };
        }
        if new_range.start >= new_range.end || new_range.start + 1 >= new_range.end {
            return ToEngineMessage::ByteRangeRefreshRefused {
                requested_range: new_range,
                reuse: reuse_worker,
            };
        }

        self.byte_range = new_range;
        worker_log!(
            self,
            "#{} Byte range refreshed {}",
            self.worker_number,
            self.byte_range
        );
        ToEngineMessage::ByteRangeRefreshSuccess {
            requested_range: self.byte_range.clone(),
            reuse: reuse_worker,
        }
    }

    /// Adds the received bytes to the buffer and flushes to disk periodically.
    /// Returns true if the byte range has been downloaded and should terminate the connection.
    /// TODO: Gracefully handle poisoned locks to send panic to the engine and recover
    async fn process_chunk(&mut self, data: Frame<Bytes>) -> anyhow::Result<(bool, Duration)> {
        let Some(chunk) = data.data_ref().cloned() else {
            // trailers or other non-data frames
            return Ok((false, Duration::ZERO));
        };
        if chunk.is_empty() {
            return Ok((false, Duration::ZERO));
        }
        if !self.status_downloading {
            self.progress.lock_anyhow()?.status = Status::Downloading;
            self.status_downloading = true;
            self.send_to_engine(ToEngineMessage::ConnectionSuccess)
                .await;
        }
        let expected_len = if self.download_info.supports_range {
            self.byte_range.len()
        } else {
            self.download_info.file_size
        };
        let remaining = expected_len.saturating_sub(self.total_request_bytes_received);
        if remaining == 0 {
            worker_log!(self, "Dropping chunk received after range boundary");
            self.flush_buffer()?;
            self.terminated_on_completion = true;
            self.set_download_complete();
            return Ok((true, Duration::ZERO));
        }
        // Never accept bytes beyond the assigned range. The range may have been shrunk by a
        // refresh, or the server may send more than requested.
        let exceeded = chunk.len() as u64 > remaining;
        let chunk = if exceeded {
            chunk.slice(0..remaining as usize)
        } else {
            chunk
        };
        let chunk_size = chunk.len() as u64;
        self.update_received_bytes(chunk_size);
        self.calculate_speed(chunk_size);
        self.data_buffer.push(chunk);
        self.calculate_flush_threshold();
        self.update_download_progress();
        if exceeded || self.download_match_end_byte() {
            worker_log!(
                self,
                "Range end reached (exceeded: {}): Current range: {}-{}, total_req: {}",
                exceeded,
                self.byte_range.start,
                self.byte_range.end,
                self.total_request_bytes_received
            );
            self.flush_buffer()?;
            if self.download_info.supports_range {
                // Safety net: remove any temp bytes past the (possibly refreshed) end byte
                self.cut_temp_files().await?;
            }
            self.terminated_on_completion = true;
            self.set_download_complete();
            return Ok((true, Duration::ZERO));
        }
        if self.temp_bytes_received > self.buffer_flush_threshold {
            self.flush_buffer()?;
        }
        let wait = self
            .rate_limiter
            .as_ref()
            .map(|l| l.lock().unwrap().consume(chunk_size))
            .unwrap_or(Duration::ZERO);
        Ok((false, wait))
    }

    /// Cuts the excess bytes from the downloaded temp files.
    /// After the download has started, the engine might send a refresh byte range command which updates
    /// the workers' assigned byte range. Since there is no way to customize the chunk sizes received
    /// from the http client, we calculate and cut the excess bytes from the latest flushed buffer
    /// which exceeded the newly assigned range.
    /// TODO: add logging
    async fn cut_temp_files(&mut self) -> anyhow::Result<()> {
        worker_log!(self, "Cutting temp files...");
        let temp_files = self.temp_files_sorted(true);
        let mut to_delete: Vec<&TempFileMetadata> = vec![];
        let mut new_buf_start_byte: Option<u64> = None;
        let mut new_buf_to_write: Option<Vec<u8>> = None;
        for file_meta in &temp_files {
            if self.byte_range.end < file_meta.start_byte {
                worker_log!(
                    self,
                    "Temp file to delete: {} :: {}",
                    file_meta.name,
                    file_meta.size
                );
                to_delete.push(file_meta);
                continue;
            }
            if self.byte_range.end < file_meta.end_byte {
                worker_log!(self, "File to cut {} :: {}", file_meta.name, file_meta.size);
                new_buf_start_byte = Some(file_meta.start_byte);
                let cut_len = self.byte_range.end - file_meta.start_byte + 1;
                worker_log!(self, "Cut len: {}", cut_len);
                let mut file = File::open(&file_meta.path)?;
                new_buf_to_write = Some(vec![0u8; cut_len as usize]);
                file.read_exact(new_buf_to_write.as_mut().unwrap())?;
                to_delete.push(file_meta);
            }
        }

        for to_delete_meta in &to_delete {
            self.total_bytes_received = self.total_bytes_received.saturating_sub(to_delete_meta.size);
            remove_file(&to_delete_meta.path)?;
            let pos = self
                .cached_temp_files
                .iter()
                .position(|f| f == *to_delete_meta);
            if let Some(pos) = pos {
                self.cached_temp_files.remove(pos);
            }
        }

        if let Some(buf_to_write) = new_buf_to_write {
            let new_start_byte = new_buf_start_byte.unwrap();
            let new_end_byte = new_start_byte as usize + buf_to_write.len() - 1;
            let filename = format!("{}#{}-{}", self.worker_number, new_start_byte, new_end_byte);
            let file_path = self.temp_directory().join(&filename);
            let mut file = File::create(&file_path)?;
            worker_log!(
                self,
                "#{} New file writing with range {}-{}",
                self.worker_number,
                new_start_byte,
                new_end_byte
            );
            file.write_all(&buf_to_write)?;
            let file_meta = TempFileMetadata {
                name: filename.clone(),
                start_byte: new_start_byte,
                end_byte: new_end_byte as u64,
                worker_number: self.worker_number,
                size: buf_to_write.len() as u64,
                path: file_path.clone(),
            };
            self.cached_temp_files.push(file_meta);
            self.total_bytes_received += buf_to_write.len() as u64;
        }
        {
            let mut progress = self.progress.lock_anyhow()?;
            progress.total_download_progress =
                self.total_bytes_received as f64 / self.download_info.file_size as f64;
            progress.total_bytes_received = self.total_bytes_received;
        }

        worker_log!(self, "Temp file fix complete");
        Ok(())
    }

    fn update_received_bytes(&mut self, len: u64) {
        self.temp_bytes_received += len;
        self.total_request_bytes_received += len;
        self.total_bytes_received += len;
    }

    fn calculate_speed(&mut self, len: u64) {
        self.speed_check_bytes += len;
        let total_len: u64 = self.speed_check_bytes;
        let now = now_millis();
        if self.last_speed_check_epoch_millis + SPEED_CHECK_WINDOW_MILLIS as u128 > now {
            return;
        }
        let time_check_before = self.last_speed_check_epoch_millis;
        self.last_speed_check_epoch_millis = now;
        let elapsed_sec = (now - time_check_before) as f64 / 1000.0;

        if total_len == 0 || elapsed_sec < 0.001 {
            return;
        }

        let speed_mb = (total_len as f64 / 1_000_000.0) / elapsed_sec;
        let speed_kb = (total_len as f64 / 1000.0) / elapsed_sec;
        let speed_b = total_len as f64 / elapsed_sec;

        if speed_mb > 1.0 {
            worker_log!(self, "Speed {:.2} MB/s", speed_mb);
        } else if speed_kb > 1.0 {
            worker_log!(self, "Speed {:.2} KB/s", speed_kb);
        } else {
            worker_log!(self, "Speed {:.2} B/s", speed_b);
        }
        self.speed_check_bytes = 0;
        self.progress.lock().unwrap().speed_bytes_per_sec = speed_b as u64;
    }

    fn calculate_flush_threshold(&mut self) {
        self.buffer_flush_threshold = self
            .progress
            .lock()
            .unwrap()
            .speed_bytes_per_sec
            .saturating_mul(2)
            .clamp(MIN_FLUSH, MAX_FLUSH);
    }

    fn update_download_progress(&self) {
        let mut progress = self.progress.lock().unwrap();
        progress.worker_download_progress = (self.total_request_bytes_received as f64
            / self.byte_range.len() as f64)
            .min(1.0);
        progress.total_download_progress =
            self.total_bytes_received as f64 / self.download_info.file_size as f64;
        progress.total_bytes_received = self.total_bytes_received;
        progress.range_bytes_received = self.total_request_bytes_received;
        progress.range_start = Some(self.byte_range.start);
        progress.last_response_time = now_millis();
    }

    fn flush_buffer(&mut self) -> anyhow::Result<()> {
        if self.data_buffer.is_empty() {
            return Ok(());
        }
        let temp_file_name = format!(
            "{}#{}-{}",
            self.worker_number,
            self.temp_file_start_byte(),
            self.temp_file_end_byte(),
        );
        let file_path = self.temp_directory().join(&temp_file_name);
        let mut file = File::create(&file_path)?;
        let mut temp_file_len: u64 = 0;
        for chunk in &self.data_buffer {
            file.write_all(chunk)?;
            temp_file_len += chunk.len() as u64;
        }
        if self.temp_file_start_byte() >= self.download_info.file_size {
            worker_log!(
                self,
                "Temp file starts beyond content length: {} range {} total_req {}",
                temp_file_name,
                self.byte_range,
                self.total_request_bytes_received
            );
        }
        let file_meta = TempFileMetadata {
            name: temp_file_name,
            start_byte: self.temp_file_start_byte(),
            end_byte: self.temp_file_end_byte(),
            worker_number: self.worker_number,
            size: temp_file_len,
            path: file_path.clone(),
        };
        worker_log!(self, "Flushed buffer {}", file_meta.name);
        self.cached_temp_files.push(file_meta);
        self.prev_buffer_end_byte += temp_file_len;
        self.reset_data_buffer();
        Ok(())
    }

    fn resolve_range(&mut self, reuse: bool) -> ByteRange {
        let req_start_byte = if reuse {
            self.byte_range.start
        } else {
            self.new_start_byte()
        };
        worker_log!(
            self,
            "New startbyte: {} end: {}",
            req_start_byte,
            self.byte_range.end
        );
        ByteRange::new(req_start_byte, self.byte_range.end)
    }

    /// Returns the next start byte to download. This is used for the pause/resume mechanism so that
    /// the next range is downloaded
    fn new_start_byte(&self) -> u64 {
        let files = self.temp_files_sorted(true);
        if files.is_empty() {
            return self.byte_range.start;
        }
        files.last().unwrap().end_byte + 1
    }

    /// Adds the temp files downloaded by this worker to its cache.
    fn init_temp_files_cache(&mut self) {
        if !self.cached_temp_files.is_empty() || !self.temp_directory().exists() {
            return;
        }
        let Ok(files) = list_files_in_dir(self.temp_directory()) else {
            return;
        };
        self.cached_temp_files = files
            .iter()
            .filter_map(TempFileMetadata::from_path_buf)
            .filter(|f| f.worker_number == self.worker_number)
            .collect();
    }

    fn temp_files_sorted(&self, this_range_only: bool) -> Vec<TempFileMetadata> {
        if self.cached_temp_files.is_empty() {
            return vec![];
        }
        if !this_range_only {
            let mut cloned_files = self.cached_temp_files.clone();
            cloned_files.sort_by(|a, b| a.start_byte.cmp(&b.start_byte));
            return cloned_files;
        }

        let mut in_range: Vec<TempFileMetadata> = self
            .cached_temp_files
            .iter()
            .filter(|x| x.is_in_range(self.byte_range.clone()))
            .cloned()
            .collect();

        in_range.sort_by(|a, b| a.start_byte.cmp(&b.start_byte));
        in_range
    }

    pub fn build_request(&mut self, reuse: bool) -> Result<Request<Empty<Bytes>>, http::Error> {
        let url = self.download_info.url.clone();
        let request_range = self.resolve_range(reuse);
        let mut builder = Request::builder().method("GET").uri(url);
        let has_user_agent = self
            .download_info
            .headers
            .keys()
            .any(|k| k.eq_ignore_ascii_case("user-agent"));
        if !has_user_agent {
            builder = builder.header("User-Agent", USER_AGENT);
        }
        for (key, value) in &self.download_info.headers {
            builder = builder.header(key, value);
        }
        if self.download_info.supports_range {
            let range_header = request_range.to_header();
            builder = builder.header(range_header.0, range_header.1);
        }
        let req = builder.body(Empty::<Bytes>::new())?;

        let total_existing_len = self.total_written_bytes(false);
        let total_req_received_bytes = self.total_written_bytes(true);
        let mut progress = self.progress.lock().unwrap();
        progress.worker_download_progress =
            total_req_received_bytes as f64 / self.byte_range.len() as f64;

        self.total_bytes_received = total_existing_len;
        self.total_request_bytes_received = total_req_received_bytes;
        progress.total_bytes_received = self.total_bytes_received;
        // The request continues after the bytes already on disk for this range
        progress.range_bytes_received = total_req_received_bytes;
        progress.range_start = Some(self.byte_range.start);
        progress.total_download_progress =
            self.total_bytes_received as f64 / self.download_info.file_size as f64;

        if request_range.start == self.byte_range.start {
            self.prev_buffer_end_byte = 0;
            worker_log!(self, "Request range was == with start");
        } else {
            self.prev_buffer_end_byte = request_range.start - self.byte_range.start;
            worker_log!(self, "wasn't, prev: {}", self.prev_buffer_end_byte);
        }

        Ok(req)
    }

    fn reset_status(&mut self) {
        {
            let mut progress = self.progress.lock().unwrap();
            progress.worker_download_progress = 0f64;
            progress.last_response_time = now_millis();
        }
        self.total_request_bytes_received = 0;
        self.prev_buffer_end_byte = 0;
        self.data_buffer.clear();
        self.reset_data_buffer();
    }

    /// Byte ranges are inclusive. A range is complete when exactly `range.len()` bytes
    /// have been received.
    fn download_match_end_byte(&self) -> bool {
        let expected = if self.download_info.supports_range {
            self.byte_range.len()
        } else {
            self.download_info.file_size
        };
        self.total_request_bytes_received == expected
    }

    fn temp_directory(&self) -> PathBuf {
        Path::new(&self.setting.base_temp_dir).join(self.download_info.uid.clone())
    }

    fn temp_file_start_byte(&self) -> u64 {
        self.byte_range.start + self.prev_buffer_end_byte
    }

    fn temp_file_end_byte(&self) -> u64 {
        self.byte_range.start + self.prev_buffer_end_byte + self.temp_bytes_received - 1
    }

    fn reset_data_buffer(&mut self) {
        self.data_buffer.clear();
        self.temp_bytes_received = 0;
    }

    fn set_download_complete(&mut self) {
        let total_bytes = self.total_written_bytes(false);
        self.total_bytes_received = total_bytes;
        self.status_downloading = false;
        let mut progress = self.progress.lock().unwrap();
        progress.status = Status::RangeComplete;
        progress.worker_download_progress = 1f64;
        progress.speed_bytes_per_sec = 0;
        progress.total_bytes_received = total_bytes;
        progress.total_download_progress = total_bytes as f64 / self.download_info.file_size as f64;
    }

    fn total_written_bytes(&self, this_range_only: bool) -> u64 {
        if self.cached_temp_files.is_empty() {
            return 0;
        }
        let temp_files = self.temp_files_sorted(this_range_only);
        if temp_files.is_empty() {
            return 0;
        }
        temp_files.iter().map(|f| f.size).sum()
    }
}

/// Increments the retry count based on an exponential backoff and sleeps for the specified time.
/// `retry_backoff` is used so that we can reset the backoff when it reaches 16. This is to prevent
/// unreasonably waiting for a prolonged amount of time before retrying again. This is because
/// sometimes some connections might get stuck and multiple retries are required.
async fn increment_retry_and_wait(retry_count: &mut u32, retry_backoff: &mut u32) {
    *retry_count += 1;
    *retry_backoff += 1;
    let mut delay_secs = 2u32.saturating_pow(*retry_backoff);
    if delay_secs > 16 {
        *retry_backoff = 1;
        delay_secs = 2;
    }
    tokio::time::sleep(Duration::from_secs(delay_secs as u64)).await;
}

/// Initial: The worker has not yet started a download
/// Stopped: Download is paused
/// Complete: The total download is complete
/// RangeComplete: The designated range has been fully downloaded
/// Resetting: The connection is being reset
/// Starting: The download is starting
/// Connecting: Connecting to server (no data has been received yet)
/// Failed: Download has failed
#[derive(PartialEq, Debug, Clone, Copy)]
pub enum Status {
    Initial,
    Stopped,
    Complete,
    RangeComplete,
    Resetting,
    Downloading,
    Starting,
    Connecting,
    Failed,
}
