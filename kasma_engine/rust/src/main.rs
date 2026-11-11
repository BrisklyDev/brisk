use kasma::download_engine::DownloadInfo;
use kasma::download_engine::handle::{spawn_http_engine_with_name, spawn_m3u8_engine};
use kasma::download_engine::m3u8::m3u8_download_engine::M3u8Info;
use std::collections::HashMap;
use kasma::download_engine::http::http_download_worker::Status;
use kasma::download_engine::http::message::{DownloadCommand, EngineToMainMsg};
use kasma::download_engine::setting::DownloadSetting;
use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use crossterm::terminal::{disable_raw_mode, enable_raw_mode};
use indicatif::{HumanBytes, ProgressBar, ProgressDrawTarget, ProgressStyle};
use std::io::IsTerminal;
use std::path::PathBuf;
use std::process::ExitCode;
use std::time::Duration;

const USAGE: &str = "\
kasma - a multi-connection download accelerator

USAGE:
    kasma [OPTIONS] <URL>

OPTIONS:
    -o, --output-dir <DIR>     Directory to save the file in [default: current directory]
    -n, --name <NAME>          Output file name [default: detected from the server]
    -c, --connections <N>      Maximum number of connections (1-64) [default: 8]
    -l, --limit <RATE>         Total speed limit, e.g. 500K, 2M, 1.5M (bytes/sec)
        --temp-dir <DIR>       Directory for temporary files [default: ~/.cache/kasma]
        --timeout <SECS>       Seconds without data before a connection is reset [default: 15]
        --retries <N|inf>      Max consecutive retries per connection [default: 10]
        --log                  Write engine logs to <temp-dir>/logs
        --hls                  Download the url as an HLS (m3u8) stream. Implied for .m3u8 urls.
    -q, --quiet                Don't show the progress bar
    -h, --help                 Print help
    -V, --version              Print version

KEYS (interactive terminal):
    p / space   Pause / resume
    q / Ctrl+C  Quit. Progress is kept; run the same command again to resume.
";

struct Args {
    url: String,
    output_dir: PathBuf,
    name: Option<String>,
    connections: u8,
    limit: Option<u64>,
    temp_dir: PathBuf,
    timeout_secs: u64,
    retries: Option<u32>,
    log: bool,
    quiet: bool,
    hls: bool,
}

fn default_temp_dir() -> PathBuf {
    if let Some(cache) = std::env::var_os("XDG_CACHE_HOME").filter(|v| !v.is_empty()) {
        return PathBuf::from(cache).join("kasma");
    }
    if let Some(home) = std::env::var_os("HOME").filter(|v| !v.is_empty()) {
        return PathBuf::from(home).join(".cache").join("kasma");
    }
    PathBuf::from(".kasma-temp")
}

/// Parses rates like `500K`, `2M`, `1.5MB`, `800000` into bytes per second (base 1000).
fn parse_rate(input: &str) -> Result<u64, String> {
    let s = input.trim().to_ascii_uppercase();
    let s = s.strip_suffix("/S").unwrap_or(&s);
    let s = s.strip_suffix('B').unwrap_or(s);
    let (num, mult) = match s.chars().last() {
        Some('K') => (&s[..s.len() - 1], 1_000f64),
        Some('M') => (&s[..s.len() - 1], 1_000_000f64),
        Some('G') => (&s[..s.len() - 1], 1_000_000_000f64),
        _ => (s, 1f64),
    };
    let value: f64 = num
        .trim()
        .parse()
        .map_err(|_| format!("invalid speed limit '{}'", input))?;
    let bytes = (value * mult) as u64;
    if bytes == 0 {
        return Err(format!("invalid speed limit '{}'", input));
    }
    Ok(bytes)
}

fn parse_args() -> Result<Args, String> {
    let mut args = std::env::args().skip(1);
    let mut url = None;
    let mut parsed = Args {
        url: String::new(),
        output_dir: std::env::current_dir().map_err(|e| e.to_string())?,
        name: None,
        connections: 8,
        limit: None,
        temp_dir: default_temp_dir(),
        timeout_secs: 15,
        retries: Some(10),
        log: false,
        quiet: false,
        hls: false,
    };
    while let Some(arg) = args.next() {
        let (flag, inline_value) = match arg.split_once('=') {
            Some((f, v)) if f.starts_with("--") => (f.to_string(), Some(v.to_string())),
            _ => (arg.clone(), None),
        };
        let mut value = |name: &str| -> Result<String, String> {
            inline_value
                .clone()
                .or_else(|| args.next())
                .ok_or_else(|| format!("missing value for {}", name))
        };
        match flag.as_str() {
            "-h" | "--help" => {
                print!("{}", USAGE);
                std::process::exit(0);
            }
            "-V" | "--version" => {
                println!("kasma {}", env!("CARGO_PKG_VERSION"));
                std::process::exit(0);
            }
            "-o" | "--output-dir" => parsed.output_dir = PathBuf::from(value(&flag)?),
            "-n" | "--name" => parsed.name = Some(value(&flag)?),
            "-c" | "--connections" => {
                let v = value(&flag)?;
                parsed.connections = v
                    .parse::<u8>()
                    .ok()
                    .filter(|c| (1..=64).contains(c))
                    .ok_or_else(|| format!("invalid connection count '{}' (1-64)", v))?;
            }
            "-l" | "--limit" => parsed.limit = Some(parse_rate(&value(&flag)?)?),
            "--temp-dir" => parsed.temp_dir = PathBuf::from(value(&flag)?),
            "--timeout" => {
                let v = value(&flag)?;
                parsed.timeout_secs = v
                    .parse::<u64>()
                    .ok()
                    .filter(|t| *t > 0)
                    .ok_or_else(|| format!("invalid timeout '{}'", v))?;
            }
            "--retries" => {
                let v = value(&flag)?;
                parsed.retries = if matches!(v.as_str(), "inf" | "infinite" | "-1") {
                    None
                } else {
                    Some(
                        v.parse::<u32>()
                            .map_err(|_| format!("invalid retry count '{}'", v))?,
                    )
                };
            }
            "--log" => parsed.log = true,
            "-q" | "--quiet" => parsed.quiet = true,
            "--hls" => parsed.hls = true,
            other if other.starts_with('-') && other.len() > 1 => {
                return Err(format!("unknown option '{}'", other));
            }
            _ => {
                if url.is_some() {
                    return Err(format!("unexpected argument '{}'", arg));
                }
                url = Some(arg);
            }
        }
    }
    parsed.url = url.ok_or_else(|| "missing <URL>".to_string())?;
    if !parsed.url.starts_with("http://") && !parsed.url.starts_with("https://") {
        return Err(format!(
            "unsupported url '{}': only http and https are supported",
            parsed.url
        ));
    }
    Ok(parsed)
}

fn is_hls_url(url: &str) -> bool {
    let path = url.split(['?', '#']).next().unwrap_or("").to_ascii_lowercase();
    path.ends_with(".m3u8") || path.ends_with(".m3u")
}

/// Enables raw mode for single key presses and restores the terminal when dropped.
struct RawModeGuard;

impl RawModeGuard {
    fn enable() -> Option<Self> {
        enable_raw_mode().ok().map(|_| RawModeGuard)
    }
}

impl Drop for RawModeGuard {
    fn drop(&mut self) {
        let _ = disable_raw_mode();
    }
}

enum UserAction {
    TogglePause,
    Quit,
}

fn poll_key(timeout: Duration) -> Option<UserAction> {
    if !event::poll(timeout).ok()? {
        return None;
    }
    let Event::Key(key) = event::read().ok()? else {
        return None;
    };
    if key.kind != KeyEventKind::Press {
        return None;
    }
    match key.code {
        KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => {
            Some(UserAction::Quit)
        }
        KeyCode::Char('q') | KeyCode::Esc => Some(UserAction::Quit),
        KeyCode::Char('p') | KeyCode::Char(' ') | KeyCode::Char('s') | KeyCode::Char('r') => {
            Some(UserAction::TogglePause)
        }
        _ => None,
    }
}

fn format_eta(secs: u64) -> String {
    if secs == 0 {
        return "--".to_string();
    }
    let (h, m, s) = (secs / 3600, (secs % 3600) / 60, secs % 60);
    if h > 0 {
        format!("{}h{:02}m", h, m)
    } else if m > 0 {
        format!("{}m{:02}s", m, s)
    } else {
        format!("{}s", s)
    }
}

fn main() -> ExitCode {
    let args = match parse_args() {
        Ok(a) => a,
        Err(e) => {
            eprintln!("error: {}\n\n{}", e, USAGE);
            return ExitCode::from(2);
        }
    };

    let mut builder = DownloadSetting::builder()
        .base_save_dir(&args.output_dir)
        .base_temp_dir(&args.temp_dir)
        .total_connections(args.connections)
        .reset_timeout_millis(args.timeout_secs * 1000)
        .progress_polling_milliseconds(200)
        .max_connection_retry_count(args.retries);
    if let Some(limit) = args.limit {
        builder = builder.speed_limit_bytes_per_sec(limit);
    }
    if args.log {
        builder = builder.with_logger();
    }
    let setting = builder.build();

    let mut handle = if args.hls || is_hls_url(&args.url) {
        spawn_m3u8_engine(
            setting,
            M3u8Info {
                url: args.url.clone(),
                playlist_content: None,
                uid: None,
                file_name: args.name.clone(),
                headers: HashMap::new(),
            },
        )
    } else {
        spawn_http_engine_with_name(
            setting,
            DownloadInfo::from_url(args.url.clone()),
            args.name.clone(),
        )
    };

    let interactive = std::io::stdin().is_terminal() && std::io::stderr().is_terminal();
    let show_progress = !args.quiet && std::io::stderr().is_terminal();

    let pb = ProgressBar::with_draw_target(
        None,
        if show_progress {
            ProgressDrawTarget::stderr()
        } else {
            ProgressDrawTarget::hidden()
        },
    );
    pb.set_style(
        ProgressStyle::with_template("{spinner:.green} {prefix:.bold} {msg}")
            .unwrap()
            .tick_chars("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏ "),
    );
    pb.set_prefix("Fetching file info");
    pb.enable_steady_tick(Duration::from_millis(120));

    let bar_style = ProgressStyle::with_template(
        "{prefix:.bold} [{bar:30.cyan/blue}] {percent:>3}% {bytes}/{total_bytes} {msg}",
    )
    .unwrap()
    .progress_chars("=> ");

    let raw_mode = if interactive { RawModeGuard::enable() } else { None };
    let mut paused = false;
    let mut quitting = false;
    let mut file_name = String::new();

    let result: Result<PathBuf, (String, u8)> = loop {
        // drain all pending engine events
        let mut finished = None;
        loop {
            match handle.rx.try_recv() {
                Ok(EngineToMainMsg::Info {
                    file_name: name,
                    file_size,
                    supports_range,
                }) => {
                    file_name = name.clone();
                    pb.set_style(bar_style.clone());
                    pb.set_length(file_size);
                    pb.set_prefix(name);
                    if !supports_range {
                        pb.set_message("(server does not support resuming)");
                    }
                }
                Ok(EngineToMainMsg::Progress(report)) => {
                    // The size of an HLS stream is an estimate that changes while downloading
                    if report.total_bytes > 0 {
                        pb.set_length(report.total_bytes);
                    }
                    pb.set_position(report.downloaded_bytes.min(report.total_bytes));
                    if paused {
                        pb.set_message("[paused] press p to resume");
                    } else {
                        let state = match report.status {
                            Status::Connecting => "connecting".to_string(),
                            _ => format!(
                                "{}/s eta {} ({} conn)",
                                HumanBytes(report.speed_bytes_per_sec),
                                format_eta(report.estimated_remaining_sec),
                                report.active_workers
                            ),
                        };
                        pb.set_message(state);
                    }
                }
                Ok(EngineToMainMsg::Paused) => {
                    paused = true;
                    pb.set_message("[paused] press p to resume");
                }
                Ok(EngineToMainMsg::Resumed) => {
                    paused = false;
                    pb.set_message("resuming...");
                }
                Ok(EngineToMainMsg::Assembling) => pb.set_message("assembling file..."),
                Ok(EngineToMainMsg::Complete(path)) => finished = Some(Ok(path)),
                Ok(EngineToMainMsg::Failed(reason))
                | Ok(EngineToMainMsg::NetworkError(reason)) => finished = Some(Err((reason, 1))),
                Ok(EngineToMainMsg::Terminated) => {
                    finished = Some(Err(("Download stopped".to_string(), 130)))
                }
                Ok(EngineToMainMsg::Uid(_)) => {}
                Err(tokio::sync::mpsc::error::TryRecvError::Empty) => break,
                Err(tokio::sync::mpsc::error::TryRecvError::Disconnected) => {
                    if finished.is_none() {
                        finished = Some(Err(("Engine stopped unexpectedly".to_string(), 1)));
                    }
                    break;
                }
            }
        }
        if let Some(result) = finished {
            break result;
        }

        let action = if raw_mode.is_some() {
            poll_key(Duration::from_millis(100))
        } else {
            std::thread::sleep(Duration::from_millis(100));
            None
        };
        match action {
            Some(UserAction::TogglePause) if !quitting => {
                let cmd = if paused {
                    DownloadCommand::Start
                } else {
                    DownloadCommand::Pause
                };
                let _ = handle.tx.try_send(cmd);
            }
            Some(UserAction::Quit) if !quitting => {
                quitting = true;
                pb.set_message("stopping...");
                let _ = handle.tx.try_send(DownloadCommand::Terminate);
            }
            _ => {}
        }
    };

    drop(raw_mode);
    let _ = handle.join.join();

    match result {
        Ok(path) => {
            pb.finish_and_clear();
            if !args.quiet {
                eprintln!("Downloaded {} to {}", file_name, path.display());
            }
            ExitCode::SUCCESS
        }
        Err((reason, code)) => {
            pb.abandon();
            if code == 130 {
                eprintln!("Stopped. Run the same command again to resume.");
            } else {
                eprintln!("error: {}", reason);
                if !file_name.is_empty() {
                    eprintln!("Progress is kept. Run the same command again to resume.");
                }
            }
            ExitCode::from(code)
        }
    }
}
