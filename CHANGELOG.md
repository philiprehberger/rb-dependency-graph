# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-04-09

### Added
- `Graph#reverse` — return a new graph with all edges flipped (useful for dependent analysis)
- `Graph#all_dependents_of(item)` — transitive closure of items depending on a node
- `Graph#independent?(a, b)` — check whether two nodes are mutually unreachable

## [0.2.0] - 2026-04-03

### Added
- `Graph#dependencies_of(item)` — returns direct dependencies of a node
- `Graph#all_dependencies_of(item)` — returns transitive closure of all dependencies
- `Graph#dependents_of(item)` — reverse lookup of items that depend on a node
- `Graph#path(from, to)` — BFS shortest dependency path between two nodes
- `Graph#subgraph(*items)` — extract a new graph containing only specified nodes and their edges
- `Graph#roots` — nodes with no dependencies
- `Graph#leaves` — nodes with no dependents
- `Graph#depth(item)` — maximum dependency depth for a node

## [0.1.8] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.1.7] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.1.6] - 2026-03-26

### Fixed
- Add Sponsor badge to README
- Fix license section link format

## [0.1.5] - 2026-03-24

### Fixed
- Fix stray character in CHANGELOG formatting

## [0.1.4] - 2026-03-24

### Fixed
- Remove inline comments from Development section to match template

## [0.1.3] - 2026-03-22

### Added
- Expand test coverage to 30+ examples with edge cases for empty graphs, single nodes, disconnected components, self-cycles, long chains, string/integer keys, and chaining

## [0.1.2] - 2026-03-22

### Changed
- Version bump for republishing
## [0.1.1] - 2026-03-22

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
