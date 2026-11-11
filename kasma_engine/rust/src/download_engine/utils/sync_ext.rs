use anyhow::Result;
use std::sync::{Mutex, MutexGuard};
use tokio::sync::mpsc::{Receiver, Sender};

pub trait MutexAnyhowExt<T> {
    fn lock_anyhow(&self) -> Result<MutexGuard<'_, T>>;
}

impl<T> MutexAnyhowExt<T> for Mutex<T> {
    fn lock_anyhow(&self) -> Result<MutexGuard<'_, T>> {
        self.lock().map_err(|_| anyhow::anyhow!("Poisoned mutex"))
    }
}

pub struct MpscChannel<S,R> {
    pub sender: Sender<S>,
    pub receiver: Receiver<R>,
}