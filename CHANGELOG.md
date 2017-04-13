# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.3] - 2026-03-22

### Added
- Expand test coverage to 30+ examples with edge cases for empty graphs, single nodes, disconnected components, self-cycles, long chains, string/integer keys, and chaining

## [0.1.2] - 2026-03-22

### Changed
- Version bump for republishing
n## [0.1.1] - 2026-03-22

### Changed
- Version bump for republishing

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Dependency graph construction with `add` method
- Topological sort resolution via `resolve`
- Parallel batch scheduling via `parallel_batches`
- Cycle detection with `cycle?` and `cycles`
- Support for diamond and transitive dependencies
