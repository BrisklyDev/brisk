//! C ABI used to drive the kasma engine from other languages (e.g. Dart FFI in Brisk).
//!
//! The API is handle based and fully non-blocking:
//!
//! - [`kasma_start`] spawns an engine from a JSON config and returns a handle (0 on error).
//! - [`kasma_command`] sends pause / resume / terminate to the engine.
//! - [`kasma_poll`] drains all pending engine events as a JSON array string (or null if none).
//!   The returned string must be freed with [`kasma_free_string`].
//! - [`kasma_dispose`] releases the handle. A still running engine is terminated in the
//!   background (its temp files are kept so the download can be resumed later).
//!
//! All functions catch panics so that a panic never unwinds across the FFI boundary.

use crate::download_engine::DownloadInfo;
use crate::download_engine::handle::{
    DownloadHandle, spawn_http_engine_with_name, spawn_m3u8_engine,
};
use crate::download_engine::m3u8::m3u8_download_engine::M3u8Info;
use crate::download_engine::http::http_download_worker::Status;
use crate::download_engine::http::message::{DownloadCommand, EngineToMainMsg};
use crate::download_engine::setting::DownloadSetting;
use once_cell::sync::Lazy;
use serde::Deserialize;
use serde_json::{Value, json};
use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::PathBuf;
use std::sync::Mutex;
use std::sync::atomic::{AtomicU64, Ordering};

pub const COMMAND_PAUSE: i32 = 0;
pub const COMMAND_RESUME: i32 = 1;
pub const COMMAND_TERMINATE: i32 = 2;

static DOWNLOADS: Lazy<Mutex<HashMap<u64, DownloadHandle>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static NEXT_HANDLE: AtomicU64 = AtomicU64::new(1);
static LAST_ERROR: Lazy<Mutex<Option<String>>> = Lazy::new(|| Mutex::new(None));

/// The JSON config accepted by [`kasma_start`].
#[derive(Deserialize)]
struct StartConfig {
    url: String,
    /// Unique id of the download. Temp files are stored in `<temp_dir>/<uid>`.
    uid: Option<String>,
    /// Output file name. Detected from the server if missing.
    file_name: Option<String>,
    save_dir: String,
    temp_dir: String,
    /// Known file size. Values <= 0 mean unknown (fetched by the engine).
    file_size: Option<i64>,
    supports_range: Option<bool>,
    #[serde(default = "default_connections")]
    connections: u8,
    #[serde(default = "default_timeout")]
    retry_timeout_millis: u64,
    /// Negative values mean unlimited retries.
    #[serde(default = "default_retries")]
    max_retries: i64,
    #[serde(default)]
    logger: bool,
    /// Total speed limit in bytes per second. Missing or <= 0 means unlimited.
    speed_limit: Option<i64>,
    #[serde(default)]
    headers: HashMap<String, String>,
    /// `"http"` (default) or `"m3u8"`
    #[serde(default, rename = "type")]
    kind: DownloadKind,
    /// m3u8 only: content of the (media or master) playlist. Fetched from `url` if missing.
    m3u8_content: Option<String>,
}

#[derive(Deserialize, Default)]
#[serde(rename_all = "lowercase")]
enum DownloadKind {
    #[default]
    Http,
    M3u8,
}

fn default_connections() -> u8 {
    8
}
fn default_timeout() -> u64 {
    10_000
}
fn default_retries() -> i64 {
    -1
}

fn set_last_error(err: impl Into<String>) {
    if let Ok(mut e) = LAST_ERROR.lock() {
        *e = Some(err.into());
    }
}

fn to_c_string(s: String) -> *mut c_char {
    CString::new(s.replace('\0', ""))
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut())
}

fn status_str(status: Status) -> &'static str {
    match status {
        Status::Initial => "initial",
        Status::Stopped => "paused",
        Status::Complete => "complete",
        Status::RangeComplete => "complete",
        Status::Resetting => "resetting",
        Status::Downloading => "downloading",
        Status::Starting => "connecting",
        Status::Connecting => "connecting",
        Status::Failed => "downloading",
    }
}

fn event_to_json(msg: EngineToMainMsg) -> Value {
    match msg {
        EngineToMainMsg::Uid(uid) => json!({"type": "uid", "uid": uid}),
        EngineToMainMsg::Info {
            file_name,
            file_size,
            supports_range,
        } => json!({
            "type": "info",
            "file_name": file_name,
            "file_size": file_size,
            "supports_range": supports_range,
        }),
        EngineToMainMsg::Progress(p) => json!({
            "type": "progress",
            "progress": p.progress,
            "downloaded_bytes": p.downloaded_bytes,
            "total_bytes": p.total_bytes,
            "speed": p.speed_bytes_per_sec,
            "eta_sec": p.estimated_remaining_sec,
            "eta": p.estimated_remaining,
            "status": status_str(p.status),
            "active_workers": p.active_workers,
            "workers": p.workers.iter().map(|w| json!({
                "worker": w.worker_number,
                "status": status_str(w.status),
                "speed": w.speed_bytes_per_sec,
                "start": w.range_start,
                "end": w.range_end,
                "received": w.range_received_bytes,
            })).collect::<Vec<_>>(),
            "segments": p.segments.iter().map(|s| json!({
                "start": s.start,
                "end": s.end,
                "worker": s.worker_number,
                "received": s.received_bytes,
                "complete": s.complete,
                "active": s.active,
            })).collect::<Vec<_>>(),
        }),
        EngineToMainMsg::Paused => json!({"type": "paused"}),
        EngineToMainMsg::Resumed => json!({"type": "resumed"}),
        EngineToMainMsg::Assembling => json!({"type": "assembling"}),
        EngineToMainMsg::Complete(path) => {
            json!({"type": "complete", "path": path.to_string_lossy()})
        }
        EngineToMainMsg::Failed(reason) => json!({"type": "failed", "reason": reason}),
        EngineToMainMsg::NetworkError(reason) => {
            json!({"type": "network_error", "reason": reason})
        }
        EngineToMainMsg::Terminated => json!({"type": "terminated"}),
    }
}

fn start_inner(config_json: &str) -> Result<u64, String> {
    let config: StartConfig =
        serde_json::from_str(config_json).map_err(|e| format!("Invalid config: {}", e))?;
    if config.url.is_empty() {
        return Err("url is empty".into());
    }
    let mut builder = DownloadSetting::builder()
        .base_save_dir(PathBuf::from(&config.save_dir))
        .base_temp_dir(PathBuf::from(&config.temp_dir))
        .total_connections(config.connections.max(1))
        .reset_timeout_millis(config.retry_timeout_millis.max(1000))
        .progress_polling_milliseconds(100)
        .max_connection_retry_count(if config.max_retries < 0 {
            None
        } else {
            Some(config.max_retries.min(u32::MAX as i64) as u32)
        });
    if let Some(limit) = config.speed_limit.filter(|l| *l > 0) {
        builder = builder.speed_limit_bytes_per_sec(limit as u64);
    }
    if config.logger {
        builder = builder.with_logger();
    }
    let uid = config.uid.filter(|u| !u.is_empty());
    let file_name = config.file_name.filter(|n| !n.is_empty());
    let handle = match config.kind {
        DownloadKind::Http => {
            let file_size = config.file_size.filter(|s| *s > 0).map(|s| s as u64);
            let info = DownloadInfo {
                url: config.url,
                uid,
                // Only treat the info as prefetched if both values are known
                supports_range: file_size.and(config.supports_range),
                file_size: config.supports_range.and(file_size),
                filename: None,
                headers: config.headers,
            };
            spawn_http_engine_with_name(builder.build(), info, file_name)
        }
        DownloadKind::M3u8 => {
            let info = M3u8Info {
                url: config.url,
                playlist_content: config.m3u8_content,
                uid,
                file_name,
                headers: config.headers,
            };
            spawn_m3u8_engine(builder.build(), info)
        }
    };
    let id = NEXT_HANDLE.fetch_add(1, Ordering::SeqCst);
    DOWNLOADS
        .lock()
        .map_err(|_| "registry poisoned".to_string())?
        .insert(id, handle);
    Ok(id)
}

/// Starts a new download engine. `config_json` is a UTF-8, null terminated JSON object
/// (see `StartConfig`). Returns a handle > 0, or 0 on error (see [`kasma_last_error`]).
///
/// # Safety
/// `config_json` must be a valid, null terminated C string.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kasma_start(config_json: *const c_char) -> u64 {
    let result = catch_unwind(AssertUnwindSafe(|| {
        if config_json.is_null() {
            return Err("config is null".to_string());
        }
        let config = unsafe { CStr::from_ptr(config_json) }
            .to_str()
            .map_err(|e| e.to_string())?;
        start_inner(config)
    }));
    match result {
        Ok(Ok(id)) => id,
        Ok(Err(e)) => {
            set_last_error(e);
            0
        }
        Err(_) => {
            set_last_error("panic in kasma_start");
            0
        }
    }
}

/// Sends a command to the engine: 0 = pause, 1 = resume, 2 = terminate.
/// Returns 0 on success, -1 if the handle is unknown, -2 if the command is invalid,
/// -3 if the engine has already stopped.
#[unsafe(no_mangle)]
pub extern "C" fn kasma_command(handle: u64, command: i32) -> i32 {
    catch_unwind(|| {
        let cmd = match command {
            COMMAND_PAUSE => DownloadCommand::Pause,
            COMMAND_RESUME => DownloadCommand::Start,
            COMMAND_TERMINATE => DownloadCommand::Terminate,
            _ => return -2,
        };
        let Ok(downloads) = DOWNLOADS.lock() else {
            return -1;
        };
        let Some(download) = downloads.get(&handle) else {
            return -1;
        };
        match download.tx.try_send(cmd) {
            Ok(_) => 0,
            Err(_) => -3,
        }
    })
    .unwrap_or(-1)
}

/// Returns all pending events of the engine as a JSON array, or null if there are none.
/// Once the engine has stopped and all events were consumed, `[{"type":"closed"}]` is returned.
/// The returned string must be freed with [`kasma_free_string`].
#[unsafe(no_mangle)]
pub extern "C" fn kasma_poll(handle: u64) -> *mut c_char {
    catch_unwind(AssertUnwindSafe(|| {
        let Ok(mut downloads) = DOWNLOADS.lock() else {
            return std::ptr::null_mut();
        };
        let Some(download) = downloads.get_mut(&handle) else {
            return to_c_string(json!([{"type": "closed"}]).to_string());
        };
        let mut events: Vec<Value> = vec![];
        loop {
            match download.rx.try_recv() {
                Ok(msg) => {
                    // Progress reports are snapshots: only the latest pending one matters
                    if matches!(msg, EngineToMainMsg::Progress(_))
                        && let Some(last) = events.last()
                        && last["type"] == "progress"
                    {
                        events.pop();
                    }
                    events.push(event_to_json(msg))
                }
                Err(tokio::sync::mpsc::error::TryRecvError::Empty) => break,
                Err(tokio::sync::mpsc::error::TryRecvError::Disconnected) => {
                    events.push(json!({"type": "closed"}));
                    break;
                }
            }
        }
        if events.is_empty() {
            return std::ptr::null_mut();
        }
        to_c_string(Value::Array(events).to_string())
    }))
    .unwrap_or(std::ptr::null_mut())
}

/// Releases the handle. If the engine is still running it is terminated in the background.
#[unsafe(no_mangle)]
pub extern "C" fn kasma_dispose(handle: u64) {
    let _ = catch_unwind(|| {
        let download = DOWNLOADS.lock().ok().and_then(|mut d| d.remove(&handle));
        if let Some(download) = download {
            let _ = download.tx.try_send(DownloadCommand::Terminate);
            // Dropping the handle detaches the engine thread. The engine exits on its own
            // once it has processed the terminate command (or its command channel closes).
            drop(download);
        }
    });
}

/// Frees a string returned by this library.
///
/// # Safety
/// `ptr` must be a pointer returned by [`kasma_poll`] or [`kasma_last_error`], or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn kasma_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| unsafe {
        drop(CString::from_raw(ptr));
    }));
}

/// Returns the last error of [`kasma_start`], or null. Must be freed with [`kasma_free_string`].
#[unsafe(no_mangle)]
pub extern "C" fn kasma_last_error() -> *mut c_char {
    catch_unwind(|| {
        LAST_ERROR
            .lock()
            .ok()
            .and_then(|mut e| e.take())
            .map(to_c_string)
            .unwrap_or(std::ptr::null_mut())
    })
    .unwrap_or(std::ptr::null_mut())
}

/// Returns the FFI API version. Bumped on breaking changes.
#[unsafe(no_mangle)]
pub extern "C" fn kasma_api_version() -> i32 {
    2
}
