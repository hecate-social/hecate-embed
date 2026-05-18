# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial scaffold: Rustler NIF skeleton, gen_server-per-model, facade,
  Common Test smoke suite, build script.
- Deterministic hash-based stub embedder (correct shape, garbage
  semantics) so the rest of the stack can integrate before fastembed-rs
  is wired.

### Planned
- Swap stub for `fastembed-rs` running ONNX `multilingual-e5-small`
- Tokeniser caching
- Batched inference with dirty schedulers

## [0.1.0] - YYYY-MM-DD

_Not yet released._
