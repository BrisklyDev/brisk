use http_body_util::{BodyExt, Empty};
use hyper::body::{Bytes, Incoming};
use hyper::header::{ACCEPT_RANGES, CONTENT_DISPOSITION, CONTENT_LENGTH, CONTENT_RANGE, RANGE};
use hyper::{Request, Response, StatusCode, Uri};
use hyper_rustls::HttpsConnector;
use hyper_util::client::legacy::Client;
use hyper_util::client::legacy::connect::HttpConnector;
use hyper_util::rt::{TokioExecutor, TokioTimer};
use std::collections::HashMap;
use std::error::Error as StdError;
use std::fmt;
use std::time::Duration;
use crate::download_engine::http::http_client::HttpClient;
use crate::download_engine::http::http_download_worker::USER_AGENT;

pub mod byte_range;
pub mod http_download_engine;
pub mod http_download_worker;
pub mod message;
pub mod progress;
pub mod rate_limiter;
pub(crate) mod http_client;

#[derive(Debug)]
pub enum ClientError {
    Transport(hyper_util::client::legacy::Error),
    Other(String),
}

impl From<hyper_util::client::legacy::Error> for ClientError {
    fn from(err: hyper_util::client::legacy::Error) -> Self {
        ClientError::Transport(err)
    }
}

impl From<hyper::http::Error> for ClientError {
    fn from(err: hyper::http::Error) -> Self {
        ClientError::Other(err.to_string())
    }
}

impl From<&str> for ClientError {
    fn from(err: &str) -> Self {
        ClientError::Other(err.to_string())
    }
}

impl From<String> for ClientError {
    fn from(err: String) -> Self {
        ClientError::Other(err)
    }
}

impl fmt::Display for ClientError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ClientError::Transport(e) => write!(f, "Transport error: {}", e),
            ClientError::Other(e) => write!(f, "{}", e),
        }
    }
}

impl StdError for ClientError {}

pub struct FileInfo {
    pub url: String,
    pub file_size: u64,
    pub file_name: String,
    pub supports_range: bool,
}

/// Fetches the file information (size, name and range support) of the given url.
///
/// A HEAD request is sent first. If it fails or lacks the required information, a GET request with
/// `Range: bytes=0-0` is sent instead, which also reliably detects range support (206 response).
pub async fn fetch_file_info(url: String) -> anyhow::Result<FileInfo> {
    let uri: Uri = url
        .parse()
        .map_err(|e| anyhow::anyhow!("Invalid url {}: {}", url, e))?;
    let client = HttpClient::new();
    let make_req = |method: &str, range: bool| {
        let mut builder = Request::builder()
            .method(method)
            .uri(uri.clone())
            .header("User-Agent", USER_AGENT);
        if range {
            builder = builder.header(RANGE, "bytes=0-0");
        }
        builder.body(Empty::new())
    };

    let mut file_size = None;
    let mut file_name = None;
    let mut supports_range = false;
    let mut head_error = None;
    match client.send(make_req("HEAD", false)?).await {
        Ok(resp) => {
            file_size = extract_content_length(&resp).filter(|s| *s > 0);
            file_name = extract_file_name(&resp);
            supports_range = extract_range_support(&resp);
        }
        Err(e) => head_error = Some(e),
    }

    if file_size.is_none() || !supports_range {
        match client.send(make_req("GET", true)?).await {
            Ok(resp) => {
                if resp.status() == StatusCode::PARTIAL_CONTENT {
                    supports_range = true;
                    if let Some(total) = extract_content_range_total(&resp) {
                        file_size = Some(total);
                    }
                } else {
                    supports_range = false;
                    if let Some(len) = extract_content_length(&resp).filter(|s| *s > 0) {
                        file_size = Some(len);
                    }
                }
                if file_name.is_none() {
                    file_name = extract_file_name(&resp);
                }
                // the body is dropped here without being read
            }
            Err(e) => {
                if file_size.is_none() {
                    let get_err = e.to_string();
                    match head_error.map(|e| e.to_string()) {
                        Some(head_err) if head_err != get_err => anyhow::bail!(
                            "Failed to fetch file information: {} (HEAD: {})",
                            get_err,
                            head_err
                        ),
                        _ => anyhow::bail!("Failed to fetch file information: {}", get_err),
                    }
                }
            }
        }
    }

    let file_size = file_size
        .ok_or_else(|| anyhow::anyhow!("The server did not report the file size"))?;
    let file_name = file_name
        .or_else(|| extract_file_name_from_url(url.clone()))
        .map(|n| sanitize_file_name(&n))
        .filter(|n| !n.is_empty())
        .unwrap_or_else(|| "download".to_string());
    Ok(FileInfo {
        url: url.to_string(),
        file_name,
        file_size,
        supports_range,
    })
}

fn extract_content_range_total(resp: &hyper::Response<hyper::body::Incoming>) -> Option<u64> {
    // e.g. "bytes 0-0/123456"
    resp.headers()
        .get(CONTENT_RANGE)?
        .to_str()
        .ok()?
        .rsplit('/')
        .next()?
        .trim()
        .parse::<u64>()
        .ok()
}

/// Removes path separators and other characters that are invalid in file names.
pub(crate) fn sanitize_file_name(name: &str) -> String {
    let name = name.rsplit(['/', '\\']).next().unwrap_or(name);
    name.chars()
        .filter(|c| !c.is_control() && !matches!(c, '<' | '>' | ':' | '"' | '|' | '?' | '*'))
        .collect::<String>()
        .trim()
        .trim_matches('.')
        .to_string()
}

/// Decodes percent-encoded characters (e.g. `%20`) in a url component.
fn percent_decode(input: &str) -> String {
    let bytes = input.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let hex = std::str::from_utf8(&bytes[i + 1..i + 3]).unwrap_or("");
            if let Ok(v) = u8::from_str_radix(hex, 16) {
                out.push(v);
                i += 3;
                continue;
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn extract_file_name_from_url(url: String) -> Option<String> {
    let without_query = url.split(['?', '#']).next().unwrap_or("");
    without_query
        .trim_end_matches('/')
        .rsplit('/')
        .next()
        .filter(|s| !s.is_empty() && !s.contains(':'))
        .map(percent_decode)
}

fn extract_content_length(resp: &hyper::Response<hyper::body::Incoming>) -> Option<u64> {
    resp.headers()
        .get(CONTENT_LENGTH)
        .and_then(|len| len.to_str().ok()?.parse::<u64>().ok())
}

/// Extracts the filename from a `Content-Disposition` header.
pub fn extract_filename(resp: &Response<Incoming>) -> Option<String> {
    let header_value = resp.headers().get(CONTENT_DISPOSITION)?.to_str().ok()?;
    for token in header_value.split(';') {
        let token = token.trim();
        if token.to_lowercase().starts_with("filename") {
            let filename = token.splitn(2, '=').nth(1)?.trim();
            let filename = filename
                .strip_prefix('"')
                .and_then(|f| f.strip_suffix('"'))
                .unwrap_or(filename);
            return Some(
                filename
                    .strip_prefix("UTF-8''")
                    .unwrap_or(filename)
                    .to_string(),
            );
        }
    }
    None
}

fn extract_file_name(resp: &hyper::Response<hyper::body::Incoming>) -> Option<String> {
    resp.headers().get(CONTENT_DISPOSITION).and_then(|val| {
        let val = val.to_str().ok()?;
        let parts: Vec<&str> = val.split(';').map(|p| p.trim()).collect();
        // RFC 5987 extended filename (filename*=UTF-8''name) takes precedence
        let extended = parts.iter().find_map(|part| {
            let lower = part.to_lowercase();
            if lower.starts_with("filename*=") {
                let value = &part["filename*=".len()..];
                let value = value.trim_matches('"');
                let value = match value.find("''") {
                    Some(idx) => &value[idx + 2..],
                    None => value,
                };
                Some(percent_decode(value))
            } else {
                None
            }
        });
        extended.or_else(|| {
            parts.iter().find_map(|part| {
                if part.to_lowercase().starts_with("filename=") {
                    Some(part["filename=".len()..].trim_matches('"').to_string())
                } else {
                    None
                }
            })
        })
    })
}

fn extract_range_support(resp: &hyper::Response<hyper::body::Incoming>) -> bool {
    resp.headers()
        .get(ACCEPT_RANGES)
        .and_then(|v| v.to_str().ok())
        .map_or(false, |v| v.to_ascii_lowercase().contains("bytes"))
}
