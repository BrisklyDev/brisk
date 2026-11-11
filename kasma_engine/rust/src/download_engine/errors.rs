use thiserror::Error;
use crate::download_engine::http::ClientError;

#[derive(Debug, Error)]
pub enum DownloadError {
    #[error("Transport error: {0}")]
    Transport(String),
    #[error("Other error: {0}")]
    Other(String),
    #[error("Process chunk error")]
    ProcessChunk,
    #[error("Invalid command")]
    InvalidCommand,
}

impl From<ClientError> for DownloadError {
    fn from(err: ClientError) -> Self {
        match err {
            ClientError::Transport(transport_err) => {
                DownloadError::Transport(transport_err.to_string())
            }
            ClientError::Other(other_err) => DownloadError::Other(other_err),
        }
    }
}

impl From<hyper::http::Error> for DownloadError {
    fn from(err: hyper::http::Error) -> Self {
        DownloadError::Other(err.to_string())
    }
}
