# frozen_string_literal: true

require_relative 'dependency_graph/version'

module Philiprehberger
  module DependencyGraph
    class Error < StandardError; end
  end
end

require_relative 'dependency_graph/graph'

module Philiprehberger
  module DependencyGraph

    # Create a new dependency graph
    #
    # @return [Graph] a new empty graph
    def self.new
      Graph.new
    end
  end
end
