use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

pub type SharedRateLimiter = Arc<Mutex<RateLimiter>>;

pub struct RateLimiter {
    tokens: f64,
    capacity: f64,
    refill_rate: f64,
    last_refill: Instant,
}

impl RateLimiter {
    pub fn new(bytes_per_sec: u64) -> Self {
        let rate = bytes_per_sec as f64;
        // Burst capacity: 100 ms worth of data. Keeping this small ensures the limiter
        // is accurate right from the first byte and after every pause/resume.
        let capacity = (rate / 10.0).max(4096.0);
        RateLimiter {
            tokens: 0.0,
            capacity,
            refill_rate: rate,
            last_refill: Instant::now(),
        }
    }

    pub fn shared(bytes_per_sec: u64) -> SharedRateLimiter {
        Arc::new(Mutex::new(Self::new(bytes_per_sec)))
    }

    /// Consumes `bytes` tokens and returns how long the caller should sleep before
    /// proceeding, so the effective throughput stays at or below the configured rate.
    pub fn consume(&mut self, bytes: u64) -> Duration {
        let now = Instant::now();
        let elapsed = now.duration_since(self.last_refill).as_secs_f64();
        self.tokens = (self.tokens + elapsed * self.refill_rate).min(self.capacity);
        self.last_refill = now;

        // Tokens are allowed to go negative (debt). The limiter is shared between all workers,
        // so when several workers consume concurrently, each one has to wait for the debt
        // accumulated by the others as well. Flooring at zero would let N workers each wait only
        // for their own chunk, multiplying the effective rate by N.
        self.tokens -= bytes as f64;
        if self.tokens >= 0.0 {
            Duration::ZERO
        } else {
            Duration::from_secs_f64(-self.tokens / self.refill_rate)
        }
    }
}
