use crate::download_engine::http::FileInfo;
use crate::download_engine::http::http_download_engine::HttpDownloadEngine;
use crate::download_engine::http::message::{DownloadCommand, EngineToMainMsg, EngineToWorkerMsg};
use crate::download_engine::http::progress::DownloadProgress;
use crate::download_engine::setting::DownloadSetting;
use crate::download_engine::utils::sync_ext::MpscChannel;
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::thread;
use std::thread::JoinHandle;
use strum_macros::{Display, EnumString};
use tokio::sync::mpsc;
use uuid::Uuid;

mod errors;
pub mod http;
pub mod m3u8;
mod macros;
pub mod setting;
pub mod utils;
pub mod handle;

#[derive(PartialEq, Copy, Clone, Display, EnumString)]
pub enum EngineState {
    Complete,
    WorkersComplete,
    Initial,
    Running,
}

#[derive(Clone)]
pub struct DownloadItem {
    uid: String,
    url: String,
    prefetched_info: bool,
    headers: HashMap<String, String>,
    supports_range: bool,
    file_size: u64,
    file_name: String,
}

pub struct DownloadInfo {
    pub url: String,
    pub uid: Option<String>,
    pub supports_range: Option<bool>,
    pub file_size: Option<u64>,
    pub filename: Option<String>,
    pub headers: HashMap<String, String>,
}

impl DownloadInfo {
    pub fn from_url(url: String) -> Self {
        DownloadInfo {
            url,
            uid: None,
            supports_range: None,
            file_size: None,
            filename: None,
            headers: HashMap::new(),
        }
    }
}

impl DownloadItem {
    pub fn from(file_info: &FileInfo) -> Self {
        Self {
            uid: Uuid::new_v4().to_string(),
            url: file_info.url.clone(),
            prefetched_info: false,
            headers: HashMap::new(),
            supports_range: file_info.supports_range,
            file_size: file_info.file_size,
            file_name: file_info.file_name.clone(),
        }
    }
}

pub trait RunnableTask {
    fn run(&mut self);
}
