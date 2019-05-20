# philiprehberger-dependency_graph

[![Tests](https://github.com/philiprehberger/rb-dependency-graph/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-dependency-graph/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-dependency_graph.svg)](https://rubygems.org/gems/philiprehberger-dependency_graph)
[![License](https://img.shields.io/github/license/philiprehberger/rb-dependency-graph)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Dependency resolver with topological sort and parallel batch scheduling

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-dependency_graph"
```

Or install directly:

```bash
gem install philiprehberger-dependency_graph
```

## Usage

```ruby
require "philiprehberger/dependency_graph"

graph = Philiprehberger::DependencyGraph.new
graph.add(:a)
graph.add(:b, depends_on: [:a])
graph.add(:c, depends_on: [:a])
graph.add(:d, depends_on: [:b, :c])

graph.resolve  # => [:a, :b, :c, :d] (dependencies first)
```

### Parallel Batches

```ruby
graph = Philiprehberger::DependencyGraph.new
graph.add(:a)
graph.add(:b, depends_on: [:a])
graph.add(:c, depends_on: [:a])
graph.add(:d, depends_on: [:b, :c])

graph.parallel_batches
# => [[:a], [:b, :c], [:d]]
# Batch 1: run :a
# Batch 2: run :b and :c in parallel
# Batch 3: run :d
```

### Cycle Detection

```ruby
graph = Philiprehberger::DependencyGraph.new
graph.add(:a, depends_on: [:b])
graph.add(:b, depends_on: [:a])

graph.cycle?  # => true
graph.cycles  # => [[:a, :b, :a]]
```

### Chaining

```ruby
graph = Philiprehberger::DependencyGraph.new
graph.add(:a).add(:b, depends_on: [:a]).add(:c, depends_on: [:b])
graph.resolve  # => [:a, :b, :c]
```

## API

| Method | Description |
|--------|-------------|
| `DependencyGraph.new` | Create a new empty graph |
| `Graph#add(item, depends_on:)` | Add an item with dependencies |
| `Graph#resolve` | Topological sort, dependencies first |
| `Graph#parallel_batches` | Group into parallel execution batches |
| `Graph#cycle?` | Check if the graph contains cycles |
| `Graph#cycles` | List all detected cycles |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

[MIT](LICENSE)
