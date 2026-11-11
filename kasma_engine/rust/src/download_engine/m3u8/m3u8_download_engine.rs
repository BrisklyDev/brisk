//! Download engine for HLS (m3u8) streams.
//!
//! The playlist's segments (plus the fMP4 initialization section, if any) are downloaded by up
//! to `total_connections` concurrent workers. Each worker downloads one segment at a time and
//! picks the next pending segment once done. Completed segments are stored as
//! `<temp_dir>/<uid>/<index>.ts`, which makes downloads resumable across sessions. Once all
//! segments are complete they are concatenated into the output file.

use crate::download_engine::http::http_client::HttpClient;
use crate::download_engine::http::http_download_engine::download_uid;
use crate::download_engine::http::http_download_worker::{Status, USER_AGENT};
use crate::download_engine::http::message::{
    DownloadCommand, EngineToMainMsg, ProgressReport, WorkerReport,
};
use crate::download_engine::http::rate_limiter::RateLimiter;
use crate::download_engine::m3u8::playlist::{MediaPlaylist, MediaSegment, Playlist};
use crate::download_engine::m3u8::segment_worker::{
    SegmentContext, SegmentError, SegmentJob, SharedStats, WorkerStats, download_segment,
    needs_key, segment_file_path,
};
use crate::download_engine::setting::DownloadSetting;
use crate::download_engine::utils::file::resolve_versioned_file_path;
use crate::download_engine::utils::{format_remaining, now_millis};
use crate::download_engine::{RunnableTask, http::sanitize_file_name};
use crate::engine_log;
use http_body_util::{BodyExt, Empty};
use hyper::Request;
use hyper::body::Bytes;
use std::collections::HashMap;
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tokio::sync::mpsc::{self, Receiver, Sender};
use tokio::task::JoinHandle;
use tokio::time::interval;

const LOG_FLUSH_TICKER_SECS: u64 = 1;
const SPEED_WINDOW: Duration = Duration::from_millis(1000);
const RETRY_BASE_DELAY_MILLIS: u64 = 1_000;
const MAX_RETRY_DELAY_MILLIS: u64 = 32_000;
const ASSEMBLE_BUFFER_SIZE: usize = 1 << 20;
/// Playlists and keys are small. Anything larger is not a playlist.
const MAX_PLAYLIST_SIZE: usize = 32 << 20;

pub struct M3u8Info {
    /// Url of the playlist. Relative segment urls are resolved against it.
    pub url: String,
    /// Content of the playlist, if already fetched. Fetched from `url` otherwise.
    pub playlist_content: Option<String>,
    /// Unique id of the download. Temp files are stored in `<temp_dir>/<uid>`.
    pub uid: Option<String>,
    /// Output file name. Derived from the url if missing.
    pub file_name: Option<String>,
    pub headers: HashMap<String, String>,
}

#[derive(Clone, Copy, PartialEq)]
enum UnitState {
    Pending,
    Active,
    Complete,
}

/// A downloadable unit: the initialization section or a media segment
struct Unit {
    segment: MediaSegment,
    state: UnitState,
    /// Consecutive failed attempts
    retries: u32,
    size: u64,
}

struct Worker {
    stats: SharedStats,
    task: Option<JoinHandle<()>>,
    unit: Option<usize>,
    last_speed_sample: (Instant, u64),
}

struct SegmentResult {
    worker: usize,
    unit: usize,
    result: Result<u64, SegmentError>,
}

enum LoopExit {
    Complete(PathBuf),
    Terminated,
    Failed(String),
    NetworkError(String),
}

pub struct M3u8DownloadEngine {
    setting: DownloadSetting,
    info: M3u8Info,
    uid: String,
    file_name: String,
    from_main_rx: Receiver<DownloadCommand>,
    to_main_tx: Sender<EngineToMainMsg>,
    log_buffer: String,
    units: Vec<Unit>,
    keys: HashMap<String, [u8; 16]>,
    workers: Vec<Worker>,
    result_tx: Sender<SegmentResult>,
    result_rx: Receiver<SegmentResult>,
    ctx: Option<Arc<SegmentContext>>,
    paused: bool,
    last_eta_calc: Option<Instant>,
    estimated_remaining_sec: u64,
    estimated_remaining: String,
}

impl RunnableTask for M3u8DownloadEngine {
    fn run(&mut self) {
        let threads = (self.setting.total_connections as usize).clamp(1, 4);
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(threads)
            .enable_all()
            .build()
            .unwrap()
            .block_on(self.run_async());
    }
}

impl M3u8DownloadEngine {
    pub fn new(
        from_main_rx: Receiver<DownloadCommand>,
        to_main_tx: Sender<EngineToMainMsg>,
        info: M3u8Info,
        setting: DownloadSetting,
    ) -> Self {
        let (result_tx, result_rx) = mpsc::channel(100);
        M3u8DownloadEngine {
            setting,
            uid: info.uid.clone().unwrap_or_default(),
            file_name: info.file_name.clone().unwrap_or_default(),
            info,
            from_main_rx,
            to_main_tx,
            log_buffer: String::new(),
            units: vec![],
            keys: HashMap::new(),
            workers: vec![],
            result_tx,
            result_rx,
            ctx: None,
            paused: false,
            last_eta_calc: None,
            estimated_remaining_sec: 0,
            estimated_remaining: String::new(),
        }
    }

    async fn run_async(&mut self) {
        if let Err(e) = self.init().await {
            engine_log!(self, "Failed to initialize engine! {:#}", e);
            self.flush_logs();
            let _ = self
                .to_main_tx
                .send(EngineToMainMsg::Failed(format!("{:#}", e)))
                .await;
            return;
        }
        let _ = self.to_main_tx.send(EngineToMainMsg::Uid(self.uid.clone())).await;
        let _ = self
            .to_main_tx
            .send(EngineToMainMsg::Info {
                file_name: self.file_name.clone(),
                // The size of a stream is unknown until all segments are downloaded
                file_size: 0,
                supports_range: true,
            })
            .await;
        let exit = match self.run_event_loop().await {
            Ok(exit) => exit,
            Err(e) => LoopExit::Failed(format!("{:#}", e)),
        };
        self.stop_workers();
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
        self.flush_logs();
        let _ = self.to_main_tx.send(msg).await;
    }

    /// Loads the playlist, fetches the decryption keys and restores completed segments of a
    /// previous session.
    async fn init(&mut self) -> anyhow::Result<()> {
        let client = HttpClient::new();
        let content = match self.info.playlist_content.take().filter(|c| !c.trim().is_empty()) {
            Some(content) => content,
            None => self.fetch_text(&client, &self.info.url.clone()).await?,
        };
        let playlist = match Playlist::parse(&content, &self.info.url)? {
            Playlist::Media(media) => media,
            Playlist::Master(variants) => {
                let variant = variants
                    .into_iter()
                    .max_by_key(|v| v.bandwidth)
                    .ok_or_else(|| anyhow::anyhow!("The master playlist has no variants"))?;
                engine_log!(
                    self,
                    "Master playlist: selected variant {} ({:?}, {} bps)",
                    variant.url,
                    variant.resolution,
                    variant.bandwidth
                );
                let content = self.fetch_text(&client, &variant.url).await?;
                match Playlist::parse(&content, &variant.url)? {
                    Playlist::Media(media) => media,
                    Playlist::Master(_) => anyhow::bail!("Nested master playlists are not supported"),
                }
            }
        };
        if let Some(method) = playlist.unsupported_encryption() {
            anyhow::bail!("{} encryption is not supported", method);
        }
        if self.uid.is_empty() {
            self.uid = download_uid(&self.info.url, playlist.segments.len() as u64);
        }
        if self.file_name.is_empty() {
            self.file_name = default_file_name(&self.info.url, &playlist);
        }
        self.build_units(playlist);
        self.fetch_keys(&client).await?;

        fs::create_dir_all(self.temp_dir())?;
        fs::create_dir_all(&self.setting.base_save_dir)?;
        if self.setting.logger_enabled {
            fs::create_dir_all(self.setting.base_temp_dir.join("logs"))?;
        }
        self.restore_completed_units();
        engine_log!(
            self,
            "Loaded playlist with {} units ({} already complete)",
            self.units.len(),
            self.units.iter().filter(|u| u.state == UnitState::Complete).count()
        );
        self.ctx = Some(Arc::new(SegmentContext {
            client,
            headers: self.info.headers.clone(),
            temp_dir: self.temp_dir(),
            timeout: Duration::from_millis(self.setting.reset_timeout_millis.max(1000)),
            rate_limiter: self.setting.speed_limit_bytes_per_sec.map(RateLimiter::shared),
        }));
        let worker_count = (self.setting.total_connections.max(1) as usize).min(self.units.len());
        self.workers = (0..worker_count)
            .map(|_| Worker {
                stats: Arc::new(Mutex::new(WorkerStats::new())),
                task: None,
                unit: None,
                last_speed_sample: (Instant::now(), 0),
            })
            .collect();
        Ok(())
    }

    fn build_units(&mut self, playlist: MediaPlaylist) {
        self.units = playlist
            .init_section
            .into_iter()
            .chain(playlist.segments)
            .map(|segment| Unit {
                segment,
                state: UnitState::Pending,
                retries: 0,
                size: 0,
            })
            .collect();
    }

    async fn fetch_keys(&mut self, client: &HttpClient) -> anyhow::Result<()> {
        let uris: Vec<String> = self
            .units
            .iter()
            .filter(|u| needs_key(&u.segment))
            .filter_map(|u| u.segment.key.as_ref()?.uri.clone())
            .collect();
        for uri in uris {
            if self.keys.contains_key(&uri) {
                continue;
            }
            let bytes = self.fetch_bytes(client, &uri).await?;
            let key: [u8; 16] = bytes.as_slice().try_into().map_err(|_| {
                anyhow::anyhow!("Invalid AES-128 key ({} bytes) from {}", bytes.len(), uri)
            })?;
            self.keys.insert(uri, key);
        }
        Ok(())
    }

    async fn fetch_text(&self, client: &HttpClient, url: &str) -> anyhow::Result<String> {
        let bytes = self.fetch_bytes(client, url).await?;
        String::from_utf8(bytes).map_err(|_| anyhow::anyhow!("The playlist {} is not valid text", url))
    }

    async fn fetch_bytes(&self, client: &HttpClient, url: &str) -> anyhow::Result<Vec<u8>> {
        let mut builder = Request::builder().method("GET").uri(url);
        if !self.info.headers.keys().any(|k| k.eq_ignore_ascii_case("user-agent")) {
            builder = builder.header("User-Agent", USER_AGENT);
        }
        for (key, value) in &self.info.headers {
            builder = builder.header(key, value);
        }
        let timeout = Duration::from_millis(self.setting.reset_timeout_millis.max(10_000));
        let response = tokio::time::timeout(timeout, client.send(builder.body(Empty::<Bytes>::new())?))
            .await
            .map_err(|_| anyhow::anyhow!("Request to {} timed out", url))?
            .map_err(|e| anyhow::anyhow!("Failed to fetch {}: {}", url, e))?;
        let body = tokio::time::timeout(timeout, response.into_body().collect())
            .await
            .map_err(|_| anyhow::anyhow!("Request to {} timed out", url))?
            .map_err(|e| anyhow::anyhow!("Failed to fetch {}: {}", url, e))?
            .to_bytes();
        if body.len() > MAX_PLAYLIST_SIZE {
            anyhow::bail!("Response of {} is too large", url);
        }
        Ok(body.to_vec())
    }

    fn restore_completed_units(&mut self) {
        let temp_dir = self.temp_dir();
        for (index, unit) in self.units.iter_mut().enumerate() {
            if let Ok(meta) = fs::metadata(segment_file_path(&temp_dir, index)) {
                unit.state = UnitState::Complete;
                unit.size = meta.len();
            }
        }
    }

    async fn run_event_loop(&mut self) -> anyhow::Result<LoopExit> {
        let mut progress_ticker = interval(Duration::from_millis(
            self.setting.progress_polling_frequency_millis.max(50),
        ));
        let mut log_flush_ticker = interval(Duration::from_secs(LOG_FLUSH_TICKER_SECS));
        loop {
            if self.all_complete() {
                self.send_progress();
                let _ = self.to_main_tx.try_send(EngineToMainMsg::Assembling);
                return Ok(match self.assemble_file() {
                    Ok(path) => LoopExit::Complete(path),
                    Err(e) => LoopExit::Failed(format!("Failed to assemble the file: {:#}", e)),
                });
            }
            self.schedule();
            tokio::select! {
                biased;
                cmd = self.from_main_rx.recv() => match cmd {
                    Some(DownloadCommand::Start) => self.resume(),
                    Some(DownloadCommand::Pause) => self.pause(),
                    Some(DownloadCommand::Terminate) | None => {
                        engine_log!(self, "Terminate command received");
                        return Ok(LoopExit::Terminated);
                    }
                },
                Some(result) = self.result_rx.recv() => {
                    if let Some(exit) = self.handle_result(result) {
                        return Ok(exit);
                    }
                }
                _ = progress_ticker.tick() => self.send_progress(),
                _ = log_flush_ticker.tick() => self.flush_logs(),
            }
        }
    }

    /// Assigns pending units to idle workers
    fn schedule(&mut self) {
        if self.paused {
            return;
        }
        let Some(ctx) = self.ctx.clone() else {
            return;
        };
        for worker_num in 0..self.workers.len() {
            if self.workers[worker_num].unit.is_some() {
                continue;
            }
            let Some(index) = self.units.iter().position(|u| u.state == UnitState::Pending) else {
                return;
            };
            let unit = &mut self.units[index];
            unit.state = UnitState::Active;
            let key = if needs_key(&unit.segment) {
                unit.segment
                    .key
                    .as_ref()
                    .and_then(|k| k.uri.as_ref())
                    .and_then(|uri| self.keys.get(uri))
                    .copied()
            } else {
                None
            };
            let delay = retry_delay(unit.retries);
            let job = SegmentJob {
                index,
                segment: unit.segment.clone(),
                key,
                delay,
            };
            let stats = self.workers[worker_num].stats.clone();
            let tx = self.result_tx.clone();
            let ctx = ctx.clone();
            let task = tokio::spawn(async move {
                let result = download_segment(ctx, job, stats).await;
                let _ = tx
                    .send(SegmentResult {
                        worker: worker_num,
                        unit: index,
                        result,
                    })
                    .await;
            });
            let worker = &mut self.workers[worker_num];
            worker.task = Some(task);
            worker.unit = Some(index);
        }
    }

    fn handle_result(&mut self, result: SegmentResult) -> Option<LoopExit> {
        let worker = &mut self.workers[result.worker];
        // Results of aborted tasks (pause) are ignored
        if worker.unit != Some(result.unit) {
            return None;
        }
        worker.unit = None;
        worker.task = None;
        let unit = &mut self.units[result.unit];
        match result.result {
            Ok(size) => {
                unit.state = UnitState::Complete;
                unit.size = size;
                unit.retries = 0;
                None
            }
            Err(SegmentError::Fatal(e)) => Some(LoopExit::Failed(e)),
            Err(SegmentError::Retryable(e)) => {
                unit.state = UnitState::Pending;
                unit.retries += 1;
                let retries = unit.retries;
                engine_log!(self, "{} (attempt {})", e, retries);
                if let Some(max) = self.setting.max_connection_retry_count
                    && retries > max
                {
                    return Some(LoopExit::NetworkError(format!(
                        "{} (gave up after {} retries)",
                        e, max
                    )));
                }
                None
            }
        }
    }

    fn pause(&mut self) {
        if self.paused {
            return;
        }
        engine_log!(self, "Pausing download");
        self.paused = true;
        self.stop_workers();
        let _ = self.to_main_tx.try_send(EngineToMainMsg::Paused);
        self.send_progress();
    }

    fn resume(&mut self) {
        if !self.paused {
            return;
        }
        engine_log!(self, "Resuming download");
        self.paused = false;
        let _ = self.to_main_tx.try_send(EngineToMainMsg::Resumed);
    }

    /// Aborts all running segment downloads. Their units are downloaded again from the start.
    fn stop_workers(&mut self) {
        for worker in &mut self.workers {
            if let Some(task) = worker.task.take() {
                task.abort();
            }
            if let Some(unit) = worker.unit.take() {
                let unit = &mut self.units[unit];
                if unit.state == UnitState::Active {
                    unit.state = UnitState::Pending;
                }
            }
            let mut stats = worker.stats.lock().unwrap();
            stats.status = Status::Stopped;
            stats.received = 0;
            stats.expected = None;
            stats.speed_bytes_per_sec = 0;
        }
    }

    fn all_complete(&self) -> bool {
        !self.units.is_empty() && self.units.iter().all(|u| u.state == UnitState::Complete)
    }

    fn send_progress(&mut self) {
        let now = Instant::now();
        let mut workers = Vec::with_capacity(self.workers.len());
        let mut active_fraction = 0.0;
        let mut active_bytes = 0u64;
        let mut speed = 0u64;
        for (num, worker) in self.workers.iter_mut().enumerate() {
            let mut stats = worker.stats.lock().unwrap();
            let (sample_time, sample_bytes) = worker.last_speed_sample;
            let elapsed = now.duration_since(sample_time);
            if elapsed >= SPEED_WINDOW {
                let delta = stats.lifetime_received.saturating_sub(sample_bytes);
                stats.speed_bytes_per_sec = (delta as f64 / elapsed.as_secs_f64()) as u64;
                worker.last_speed_sample = (now, stats.lifetime_received);
            }
            if worker.unit.is_none() {
                stats.speed_bytes_per_sec = 0;
            } else {
                active_bytes += stats.received;
                if let Some(expected) = stats.expected.filter(|e| *e > 0) {
                    active_fraction += (stats.received as f64 / expected as f64).min(1.0);
                }
            }
            speed += stats.speed_bytes_per_sec;
            let expected = stats.expected.unwrap_or(0);
            workers.push(WorkerReport {
                worker_number: num as u8,
                status: if worker.unit.is_none() && stats.status != Status::Stopped {
                    Status::Complete
                } else {
                    stats.status
                },
                speed_bytes_per_sec: stats.speed_bytes_per_sec,
                range_start: 0,
                range_end: expected.saturating_sub(1),
                range_received_bytes: stats.received,
            });
        }

        let total_units = self.units.len().max(1);
        let (complete_count, complete_bytes) = self
            .units
            .iter()
            .filter(|u| u.state == UnitState::Complete)
            .fold((0usize, 0u64), |(count, bytes), u| (count + 1, bytes + u.size));
        let downloaded = complete_bytes + active_bytes;
        let progress = ((complete_count as f64 + active_fraction) / total_units as f64).min(1.0);
        // The total size is estimated from the average size of the completed segments
        let estimated_total = if complete_count == 0 {
            0
        } else {
            (complete_bytes as f64 / complete_count as f64 * total_units as f64) as u64
        }
        .max(downloaded);
        self.update_eta(speed, estimated_total.saturating_sub(downloaded), complete_count > 0);

        let status = if self.paused {
            Status::Stopped
        } else if self.workers.iter().any(|w| {
            w.unit.is_some() && w.stats.lock().map(|s| s.status == Status::Downloading).unwrap_or(false)
        }) {
            Status::Downloading
        } else {
            Status::Connecting
        };
        let active_workers = workers
            .iter()
            .filter(|w| w.status == Status::Downloading)
            .count();
        let report = ProgressReport {
            progress,
            downloaded_bytes: downloaded,
            total_bytes: estimated_total,
            speed_bytes_per_sec: if self.paused { 0 } else { speed },
            estimated_remaining_sec: self.estimated_remaining_sec,
            estimated_remaining: self.estimated_remaining.clone(),
            status,
            active_workers,
            workers,
            segments: vec![],
        };
        // Never block the engine on a slow consumer. Progress reports are disposable.
        let _ = self.to_main_tx.try_send(EngineToMainMsg::Progress(report));
    }

    fn update_eta(&mut self, speed: u64, remaining_bytes: u64, estimate_known: bool) {
        if self
            .last_eta_calc
            .is_some_and(|t| t.elapsed() < Duration::from_secs(1))
        {
            return;
        }
        self.last_eta_calc = Some(Instant::now());
        if self.paused || speed == 0 || !estimate_known {
            self.estimated_remaining_sec = 0;
            self.estimated_remaining = String::new();
            return;
        }
        self.estimated_remaining_sec = remaining_bytes / speed;
        self.estimated_remaining = format_remaining(self.estimated_remaining_sec);
    }

    /// Concatenates all segment files into the output file and deletes the temp directory
    fn assemble_file(&mut self) -> anyhow::Result<PathBuf> {
        engine_log!(self, "Assembling file...");
        let save_dir = self.setting.base_save_dir.clone();
        let mut path = save_dir.join(&self.file_name);
        if path.exists() {
            path = resolve_versioned_file_path(&self.file_name, &save_dir)?;
        }
        let mut output = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(&path)?;
        let temp_dir = self.temp_dir();
        let mut buffer = vec![0u8; ASSEMBLE_BUFFER_SIZE];
        let result: anyhow::Result<u64> = (|| {
            let mut written = 0u64;
            for index in 0..self.units.len() {
                let mut input = File::open(segment_file_path(&temp_dir, index))?;
                loop {
                    let read = input.read(&mut buffer)?;
                    if read == 0 {
                        break;
                    }
                    output.write_all(&buffer[..read])?;
                    written += read as u64;
                }
            }
            output.flush()?;
            Ok(written)
        })();
        drop(output);
        let expected: u64 = self.units.iter().map(|u| u.size).sum();
        match result {
            Ok(written) if written == expected => {
                engine_log!(self, "File assembled successfully: {}", path.display());
                let _ = fs::remove_dir_all(&temp_dir);
                Ok(path)
            }
            Ok(written) => {
                let _ = fs::remove_file(&path);
                anyhow::bail!("wrote {} bytes, expected {}", written, expected)
            }
            Err(e) => {
                let _ = fs::remove_file(&path);
                Err(e)
            }
        }
    }

    fn temp_dir(&self) -> PathBuf {
        self.setting.base_temp_dir.join(&self.uid)
    }

    fn flush_logs(&mut self) {
        if self.log_buffer.is_empty() {
            return;
        }
        if self.setting.logger_enabled && !self.uid.is_empty() {
            let path = self
                .setting
                .base_temp_dir
                .join("logs")
                .join(format!("{}_log.txt", self.uid));
            if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) {
                let _ = file.write_all(self.log_buffer.as_bytes());
            }
        }
        self.log_buffer.clear();
    }
}

fn retry_delay(retries: u32) -> Duration {
    if retries == 0 {
        return Duration::ZERO;
    }
    let millis = RETRY_BASE_DELAY_MILLIS
        .saturating_mul(1 << (retries - 1).min(16))
        .min(MAX_RETRY_DELAY_MILLIS);
    Duration::from_millis(millis)
}

/// `<playlist name>.ts`, or `.mp4` for fMP4 streams
fn default_file_name(url: &str, playlist: &MediaPlaylist) -> String {
    let path_name = url::Url::parse(url)
        .ok()
        .and_then(|u| u.path_segments()?.next_back().map(|s| s.to_string()))
        .unwrap_or_default();
    let stem = path_name
        .rsplit_once('.')
        .map(|(stem, _)| stem.to_string())
        .unwrap_or(path_name);
    let stem = sanitize_file_name(&stem);
    let stem = if stem.is_empty() { "video".to_string() } else { stem };
    let extension = if playlist.is_fragmented_mp4() { "mp4" } else { "ts" };
    format!("{}.{}", stem, extension)
}
