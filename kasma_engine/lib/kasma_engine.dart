/// The kasma engine is a native (Rust) library. This plugin only builds and bundles it with
/// the application. The Dart bindings live in `brisk_download_engine`
/// (`src/download_engine/kasma`), which loads the library at runtime.
library;

const kasmaLinuxLibrary = 'libkasma.so';

const kasmaWindowsLibrary = 'kasma.dll';
