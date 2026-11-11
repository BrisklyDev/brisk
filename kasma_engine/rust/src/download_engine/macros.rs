use crate::download_engine::utils::now_millis;

/// logs the error and returns Ok to terminate execution without causing an engine restart
#[macro_export]
macro_rules! engine_warn {
    ($self:expr, $($arg:tt)*) => {{
        $self.log_buffer.push_str(&format!(
            "@{} #engine {}",
            now_millis(),
            format!($($arg)*)
        ));
        $self.log_buffer.push('\n');
        return Ok(());
    }};
}
#[macro_export]
macro_rules! unwrap_or_bail {
    ($opt:expr, $($arg:tt)*) => {
        match $opt {
            Some(val) => val,
            None => anyhow::bail!($($arg)*),
        }
    };
}

#[macro_export]
macro_rules! engine_log {
    ($self:expr, $($arg:tt)*) => {{
        $self.log_buffer.push_str(&format!(
            "@{} #engine {}",
            now_millis(),
            format!($($arg)*)
        ));
        $self.log_buffer.push('\n');
    }};
}

#[macro_export]
macro_rules! worker_log {
    ($self:expr, $($arg:tt)*) => {{
        $self.log_buffer.push_str(&format!(
            "@{} #{} {}",
            now_millis(),
            $self.worker_number,
            format!($($arg)*)
        ));
        $self.log_buffer.push('\n');
    }};
}
