use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};
use std::{fs, io};

pub mod file;
pub mod sync_ext;

pub fn now_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("Time went backwards!")
        .as_millis()
}

/// Formats the estimated remaining time, e.g. "2 Minutes, 5 Seconds". Empty for 0.
pub fn format_remaining(remaining_sec: u64) -> String {
    let days = (remaining_sec % 31536000) / 86400;
    let hours = ((remaining_sec % 31536000) % 86400) / 3600;
    let minutes = (((remaining_sec % 31536000) % 86400) % 3600) / 60;
    let seconds = (((remaining_sec % 31536000) % 86400) % 3600) % 60;

    fn format_unit(value: u64, unit: &str) -> String {
        format!("{} {}{}", value, unit, if value == 1 { "" } else { "s" })
    }

    if days >= 1 {
        format!("{}, {}", format_unit(days, "Day"), format_unit(hours, "Hour"))
    } else if hours >= 1 {
        format!("{}, {}", format_unit(hours, "Hour"), format_unit(minutes, "Minute"))
    } else if minutes >= 1 {
        format!("{}, {}", format_unit(minutes, "Minute"), format_unit(seconds, "Second"))
    } else if remaining_sec == 0 {
        String::new()
    } else {
        format_unit(remaining_sec, "Second")
    }
}
