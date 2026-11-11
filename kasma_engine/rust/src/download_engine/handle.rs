use crate::download_engine::http::http_download_engine::HttpDownloadEngine;
use crate::download_engine::http::message::{DownloadCommand, EngineToMainMsg};
use crate::download_engine::m3u8::m3u8_download_engine::{M3u8DownloadEngine, M3u8Info};
use crate::download_engine::setting::DownloadSetting;
use crate::download_engine::{DownloadInfo, RunnableTask};
use std::thread;
use std::thread::JoinHandle;
use tokio::sync::mpsc;

pub struct DownloadHandle {
    pub tx: mpsc::Sender<DownloadCommand>,
    pub rx: mpsc::Receiver<EngineToMainMsg>,
    pub join: JoinHandle<()>,
}

impl DownloadHandle {
    pub async fn pause(&self) {
        let _ = self.tx.send(DownloadCommand::Pause).await;
    }

    pub async fn start(&self) {
        let _ = self.tx.send(DownloadCommand::Start).await;
    }

    /// Changes the total speed limit of the running download. `None` removes the limit.
    pub async fn set_speed_limit(&self, bytes_per_sec: Option<u64>) {
        let _ = self.tx.send(DownloadCommand::SetSpeedLimit(bytes_per_sec)).await;
    }

    /// Stops the download, keeping the temp files so that it can be resumed later.
    pub async fn terminate(&self) {
        let _ = self.tx.send(DownloadCommand::Terminate).await;
    }

    pub async fn next_event(&mut self) -> Option<EngineToMainMsg> {
        self.rx.recv().await
    }
}

pub fn spawn_http_engine(setting: DownloadSetting, info: DownloadInfo) -> DownloadHandle {
    spawn_http_engine_with_name(setting, info, None)
}

/// Spawns the engine on its own thread. `output_file_name` overrides the name of the
/// downloaded file.
pub fn spawn_http_engine_with_name(
    setting: DownloadSetting,
    info: DownloadInfo,
    output_file_name: Option<String>,
) -> DownloadHandle {
    let (engine_to_main_tx, engine_to_main_rx) = mpsc::channel::<EngineToMainMsg>(100);
    let (main_to_engine_tx, main_to_engine_rx) = mpsc::channel::<DownloadCommand>(100);
    let handle = thread::Builder::new()
        .name("kasma-engine".to_string())
        .spawn(move || {
            HttpDownloadEngine::new(
                main_to_engine_rx,
                engine_to_main_tx,
                info,
                setting,
                output_file_name,
            )
            .0
            .run();
        })
        .expect("Failed to spawn engine thread");
    DownloadHandle {
        tx: main_to_engine_tx,
        rx: engine_to_main_rx,
        join: handle,
    }
}

pub fn spawn_m3u8_engine(setting: DownloadSetting, info: M3u8Info) -> DownloadHandle {
    let (engine_to_main_tx, engine_to_main_rx) = mpsc::channel::<EngineToMainMsg>(100);
    let (main_to_engine_tx, main_to_engine_rx) = mpsc::channel::<DownloadCommand>(100);
    let handle = thread::Builder::new()
        .name("kasma-m3u8-engine".to_string())
        .spawn(move || {
            M3u8DownloadEngine::new(main_to_engine_rx, engine_to_main_tx, info, setting).run();
        })
        .expect("Failed to spawn engine thread");
    DownloadHandle {
        tx: main_to_engine_tx,
        rx: engine_to_main_rx,
        join: handle,
    }
}
