use crate::download_engine::http::byte_range::ByteRange;
use once_cell::sync::Lazy;
use regex::Regex;
use std::path::{Path, PathBuf};
use std::{fs, io};

static VERSIONED_FILENAME_REGEX: Lazy<Regex> = Lazy::new(|| Regex::new(r"^.+_\d+$").unwrap());

#[derive(Clone, PartialEq, Eq)]
pub struct TempFileMetadata {
    pub name: String,
    pub path: PathBuf,
    pub start_byte: u64,
    pub end_byte: u64,
    pub worker_number: u8,
    pub size: u64,
}

impl TempFileMetadata {
    /// Returns true if the temp file's byte range overlaps with the given (inclusive) range.
    pub fn is_in_range(&self, range: ByteRange) -> bool {
        self.start_byte <= range.end && self.end_byte >= range.start
    }

    /// Parses the temp file metadata from its path. Returns `None` for files that do not follow
    /// the `worker#start-end` naming scheme.
    pub fn from_path_buf(path: &PathBuf) -> Option<TempFileMetadata> {
        let meta = fs::metadata(path).ok()?;
        let name = path.file_name()?.to_str()?;
        let (worker_number, start_byte, end_byte) = extract_worker_and_range(name)?;
        Some(TempFileMetadata {
            worker_number,
            start_byte,
            end_byte,
            name: name.to_string(),
            path: path.clone(),
            size: meta.len(),
        })
    }
}

fn extract_worker_and_range(s: &str) -> Option<(u8, u64, u64)> {
    let parts: Vec<&str> = s.split('#').collect();
    if parts.len() != 2 {
        return None;
    }
    let worker = parts[0].parse::<u8>().ok()?;
    let range_part = parts[1];
    let range: Vec<&str> = range_part.split('-').collect();
    if range.len() != 2 {
        return None;
    }
    let start = range[0].parse::<u64>().ok()?;
    let end = range[1].parse::<u64>().ok()?;
    Some((worker, start, end))
}

pub fn list_temp_files_sorted<P: AsRef<Path>>(dir: P) -> io::Result<Vec<TempFileMetadata>> {
    let files = list_files_in_dir(dir)?;
    let mut files_sorted = files
        .iter()
        .filter_map(TempFileMetadata::from_path_buf)
        .collect::<Vec<TempFileMetadata>>();
    files_sorted.sort_by(|a, b| {
        a.start_byte
            .cmp(&b.start_byte)
            .then(a.end_byte.cmp(&b.end_byte))
    });
    Ok(files_sorted)
}
pub fn list_files_in_dir<P: AsRef<Path>>(dir: P) -> io::Result<Vec<PathBuf>> {
    let mut files = Vec::new();
    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        if path.is_file() {
            files.push(path);
        }
    }
    Ok(files)
}

pub fn resolve_versioned_file_path<S: AsRef<str>, P: AsRef<Path>>(
    filename: S,
    dir: P,
) -> anyhow::Result<PathBuf> {
    if !dir.as_ref().exists() {
        fs::create_dir_all(&dir)?;
    }
    let original = dir.as_ref().join(filename.as_ref());
    let extension = original
        .extension()
        .map(|e| e.to_string_lossy().into_owned());
    let mut raw_name = original
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| filename.as_ref().to_string());
    if VERSIONED_FILENAME_REGEX.is_match(&raw_name) {
        if let Some(idx) = raw_name.rfind('_') {
            raw_name.truncate(idx);
        }
    }
    let mut file = original;
    let mut version = 1;
    while file.exists() {
        version += 1;
        let versioned = match &extension {
            Some(ext) => format!("{}_{}.{}", raw_name, version, ext),
            None => format!("{}_{}", raw_name, version),
        };
        file = dir.as_ref().join(versioned);
    }

    Ok(file)
}
