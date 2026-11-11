use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

pub type SharedRateLimiter = Arc<Mutex<RateLimiter>>;

/// Token bucket shared between all workers of a download.
/// A rate of `None` means unlimited: [`RateLimiter::consume`] never asks the caller to wait.
/// The rate can be changed at any time with [`RateLimiter::set_rate`], and since workers hold
/// the same `Arc`, the change applies to all of them on their next chunk.
pub struct RateLimiter {
    tokens: f64,
    capacity: f64,
    refill_rate: Option<f64>,
    last_refill: Instant,
}

impl RateLimiter {
    pub fn new(bytes_per_sec: Option<u64>) -> Self {
        let mut limiter = RateLimiter {
            tokens: 0.0,
            capacity: 0.0,
            refill_rate: None,
            last_refill: Instant::now(),
        };
        limiter.set_rate(bytes_per_sec);
        limiter
    }

    pub fn shared(bytes_per_sec: Option<u64>) -> SharedRateLimiter {
        Arc::new(Mutex::new(Self::new(bytes_per_sec)))
    }

    /// Changes the rate. `None` or `Some(0)` removes the limit.
    /// Any accumulated debt is discarded so the new rate takes effect immediately.
    pub fn set_rate(&mut self, bytes_per_sec: Option<u64>) {
        let rate = bytes_per_sec.filter(|r| *r > 0).map(|r| r as f64);
        // Burst capacity: 100 ms worth of data. Keeping this small ensures the limiter
        // is accurate right from the first byte and after every pause/resume.
        self.capacity = rate.map(|r| (r / 10.0).max(4096.0)).unwrap_or(0.0);
        self.refill_rate = rate;
        self.tokens = 0.0;
        self.last_refill = Instant::now();
    }

    pub fn rate(&self) -> Option<u64> {
        self.refill_rate.map(|r| r as u64)
    }

    /// Consumes `bytes` tokens and returns how long the caller should sleep before
    /// proceeding, so the effective throughput stays at or below the configured rate.
    pub fn consume(&mut self, bytes: u64) -> Duration {
        let Some(refill_rate) = self.refill_rate else {
            return Duration::ZERO;
        };
        let now = Instant::now();
        let elapsed = now.duration_since(self.last_refill).as_secs_f64();
        self.tokens = (self.tokens + elapsed * refill_rate).min(self.capacity);
        self.last_refill = now;

        // Tokens are allowed to go negative (debt). The limiter is shared between all workers,
        // so when several workers consume concurrently, each one has to wait for the debt
        // accumulated by the others as well. Flooring at zero would let N workers each wait only
        // for their own chunk, multiplying the effective rate by N.
        self.tokens -= bytes as f64;
        if self.tokens >= 0.0 {
            Duration::ZERO
        } else {
            Duration::from_secs_f64(-self.tokens / refill_rate)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unlimited_never_waits() {
        let mut l = RateLimiter::new(None);
        assert_eq!(l.consume(10_000_000), Duration::ZERO);
        let mut l = RateLimiter::new(Some(0));
        assert_eq!(l.consume(10_000_000), Duration::ZERO);
    }

    #[test]
    fn set_rate_changes_limit_and_clears_debt() {
        let mut l = RateLimiter::new(Some(1000));
        assert!(l.consume(10_000) >= Duration::from_secs(9));
        l.set_rate(None);
        assert_eq!(l.consume(10_000), Duration::ZERO);
        l.set_rate(Some(1_000_000));
        assert!(l.consume(10_000) <= Duration::from_millis(11));
        assert_eq!(l.rate(), Some(1_000_000));
    }
}
