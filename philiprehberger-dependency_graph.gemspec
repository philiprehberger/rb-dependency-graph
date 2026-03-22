# frozen_string_literal: true

require_relative 'lib/philiprehberger/dependency_graph/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-dependency_graph'
  spec.version       = Philiprehberger::DependencyGraph::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Dependency resolver with topological sort and parallel batch scheduling'
  spec.description   = 'Build and resolve dependency graphs using topological sort, detect cycles, ' \
                       'and generate parallel execution batches for concurrent task scheduling.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-dependency-graph'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
