//! Downloads a single HLS segment: request, (optional) decryption and writing the completed
//! segment file. A segment counts as complete once `<index>.ts` exists in the temp directory.

use crate::download_engine::http::http_client::HttpClient;
use crate::download_engine::http::http_download_worker::{Status, USER_AGENT};
use crate::download_engine::http::rate_limiter::SharedRateLimiter;
use crate::download_engine::m3u8::crypto::{decrypt_aes128, implicit_iv};
use crate::download_engine::m3u8::playlist::{EncryptionMethod, MediaSegment};
use http_body_util::{BodyExt, Empty};
use hyper::StatusCode;
use hyper::body::Bytes;
use hyper::header::{CONTENT_LENGTH, RANGE};
use hyper::Request;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

pub const SEGMENT_FILE_EXTENSION: &str = "ts";
const PART_FILE_EXTENSION: &str = "part";

pub struct SegmentContext {
    pub client: HttpClient,
    pub headers: HashMap<String, String>,
    pub temp_dir: PathBuf,
    /// Maximum time without receiving data before the request is considered failed
    pub timeout: Duration,
    pub rate_limiter: Option<SharedRateLimiter>,
}

pub struct WorkerStats {
    pub status: Status,
    /// Bytes received for the current segment
    pub received: u64,
    /// Expected size of the current segment, if the server reported it
    pub expected: Option<u64>,
    /// Bytes received by this worker since it was created. Used for the speed calculation.
    pub lifetime_received: u64,
    pub speed_bytes_per_sec: u64,
}

impl WorkerStats {
    pub fn new() -> Self {
        WorkerStats {
            status: Status::Initial,
            received: 0,
            expected: None,
            lifetime_received: 0,
            speed_bytes_per_sec: 0,
        }
    }
}

pub type SharedStats = Arc<Mutex<WorkerStats>>;

pub struct SegmentJob {
    /// Index of the unit in the engine. Used as the temp file name.
    pub index: usize,
    pub segment: MediaSegment,
    pub key: Option<[u8; 16]>,
    /// Wait before sending the request (retry backoff)
    pub delay: Duration,
}

pub enum SegmentError {
    /// Network errors, timeouts and bad responses. The segment can be retried.
    Retryable(String),
    /// Errors that won't go away by retrying (e.g. decryption or disk errors)
    Fatal(String),
}

impl std::fmt::Display for SegmentError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SegmentError::Retryable(e) | SegmentError::Fatal(e) => write!(f, "{}", e),
        }
    }
}

pub fn segment_file_path(temp_dir: &Path, index: usize) -> PathBuf {
    temp_dir.join(format!("{}.{}", index, SEGMENT_FILE_EXTENSION))
}

/// Downloads the segment and returns the size of the written (decrypted) segment file
pub async fn download_segment(
    ctx: Arc<SegmentContext>,
    job: SegmentJob,
    stats: SharedStats,
) -> Result<u64, SegmentError> {
    {
        let mut s = stats.lock().unwrap();
        s.status = Status::Connecting;
        s.received = 0;
        s.expected = None;
    }
    if !job.delay.is_zero() {
        tokio::time::sleep(job.delay).await;
    }
    let mut data = fetch(&ctx, &job, &stats).await?;
    if let Some(key) = &job.key {
        let iv = job
            .segment
            .key
            .as_ref()
            .and_then(|k| k.iv)
            .unwrap_or_else(|| implicit_iv(job.segment.sequence));
        let len = decrypt_aes128(&mut data, key, &iv)
            .map_err(|e| SegmentError::Fatal(format!("Segment {}: {}", job.index, e)))?;
        data.truncate(len);
    }
    write_segment(&ctx.temp_dir, job.index, &data)
        .map_err(|e| SegmentError::Fatal(format!("Failed to write segment {}: {}", job.index, e)))?;
    stats.lock().unwrap().status = Status::RangeComplete;
    Ok(data.len() as u64)
}

async fn fetch(
    ctx: &SegmentContext,
    job: &SegmentJob,
    stats: &SharedStats,
) -> Result<Vec<u8>, SegmentError> {
    let retryable = |e: String| SegmentError::Retryable(format!("Segment {}: {}", job.index, e));
    let mut builder = Request::builder().method("GET").uri(&job.segment.url);
    if !ctx.headers.keys().any(|k| k.eq_ignore_ascii_case("user-agent")) {
        builder = builder.header("User-Agent", USER_AGENT);
    }
    for (key, value) in &ctx.headers {
        builder = builder.header(key, value);
    }
    if let Some(range) = &job.segment.sub_range {
        builder = builder.header(RANGE, range.to_header());
    }
    let request = builder
        .body(Empty::<Bytes>::new())
        .map_err(|e| SegmentError::Fatal(format!("Invalid segment request: {}", e)))?;
    let response = tokio::time::timeout(ctx.timeout, ctx.client.send(request))
        .await
        .map_err(|_| retryable("connection timed out".into()))?
        .map_err(|e| retryable(e.to_string()))?;

    // The server ignored the Range header and sent the whole resource
    let skip = match &job.segment.sub_range {
        Some(range) if response.status() != StatusCode::PARTIAL_CONTENT => range.offset,
        _ => 0,
    };
    let expected = match &job.segment.sub_range {
        Some(range) => Some(range.length),
        None => response
            .headers()
            .get(CONTENT_LENGTH)
            .and_then(|v| v.to_str().ok()?.parse::<u64>().ok()),
    };
    {
        let mut s = stats.lock().unwrap();
        s.status = Status::Downloading;
        s.expected = expected;
    }

    let mut body = response.into_body();
    let mut data: Vec<u8> = Vec::with_capacity(expected.unwrap_or(0).min(64 << 20) as usize);
    let mut skipped = 0u64;
    let mut last_data = Instant::now();
    loop {
        let frame = tokio::time::timeout(ctx.timeout, body.frame())
            .await
            .map_err(|_| retryable(format!("no data received for {:?}", last_data.elapsed())))?;
        let Some(frame) = frame else {
            break;
        };
        let frame = frame.map_err(|e| retryable(e.to_string()))?;
        let Ok(chunk) = frame.into_data() else {
            continue;
        };
        last_data = Instant::now();
        let mut chunk = &chunk[..];
        if skipped < skip {
            let n = ((skip - skipped) as usize).min(chunk.len());
            skipped += n as u64;
            chunk = &chunk[n..];
        }
        if let Some(limit) = expected {
            let remaining = limit.saturating_sub(data.len() as u64) as usize;
            chunk = &chunk[..chunk.len().min(remaining)];
        }
        data.extend_from_slice(chunk);
        {
            let mut s = stats.lock().unwrap();
            s.received = data.len() as u64;
            s.lifetime_received += chunk.len() as u64;
        }
        let wait = ctx
            .rate_limiter
            .as_ref()
            .map(|l| l.lock().unwrap().consume(chunk.len() as u64))
            .unwrap_or(Duration::ZERO);
        if !wait.is_zero() {
            tokio::time::sleep(wait).await;
        }
        if expected.is_some_and(|e| data.len() as u64 >= e) {
            break;
        }
    }
    if let Some(expected) = expected
        && (data.len() as u64) < expected
    {
        return Err(retryable(format!(
            "connection closed after {} of {} bytes",
            data.len(),
            expected
        )));
    }
    if data.is_empty() {
        return Err(retryable("empty response".into()));
    }
    Ok(data)
}

/// Writes the segment to a part file first and renames it, so that a segment file only exists
/// once it has been completely written.
fn write_segment(temp_dir: &Path, index: usize, data: &[u8]) -> std::io::Result<()> {
    let part = temp_dir.join(format!("{}.{}", index, PART_FILE_EXTENSION));
    std::fs::write(&part, data)?;
    std::fs::rename(&part, segment_file_path(temp_dir, index))
}

pub fn needs_key(segment: &MediaSegment) -> bool {
    segment
        .key
        .as_ref()
        .is_some_and(|k| k.method == EncryptionMethod::Aes128)
}
