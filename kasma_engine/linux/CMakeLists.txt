# Builds the kasma Rust engine with cargo and bundles libkasma.so with the application.
cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "kasma_engine")
project(${PROJECT_NAME} LANGUAGES C)

set(KASMA_RUST_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../rust")
set(KASMA_TARGET_DIR "${CMAKE_BINARY_DIR}/kasma_rust_target")
set(KASMA_LIBRARY "${KASMA_TARGET_DIR}/release/libkasma.so")

find_program(CARGO_EXECUTABLE cargo HINTS "$ENV{CARGO_HOME}/bin" "$ENV{HOME}/.cargo/bin")
if(NOT CARGO_EXECUTABLE)
  message(FATAL_ERROR "cargo was not found. Install Rust (https://rustup.rs) to build the kasma engine.")
endif()

file(GLOB_RECURSE KASMA_SOURCES CONFIGURE_DEPENDS "${KASMA_RUST_DIR}/src/*.rs")
add_custom_command(
  OUTPUT "${KASMA_LIBRARY}"
  COMMAND "${CARGO_EXECUTABLE}" build --release --lib
          --manifest-path "${KASMA_RUST_DIR}/Cargo.toml"
          --target-dir "${KASMA_TARGET_DIR}"
  DEPENDS ${KASMA_SOURCES} "${KASMA_RUST_DIR}/Cargo.toml" "${KASMA_RUST_DIR}/Cargo.lock"
  COMMENT "Building kasma engine (Rust)"
  USES_TERMINAL
  VERBATIM
)
add_custom_target(kasma_engine_rust ALL DEPENDS "${KASMA_LIBRARY}")

# Installed into the bundle's lib directory by flutter/generated_plugins.cmake
set(kasma_engine_bundled_libraries "${KASMA_LIBRARY}" PARENT_SCOPE)
