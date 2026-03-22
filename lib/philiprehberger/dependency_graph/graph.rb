# frozen_string_literal: true

module Philiprehberger
  module DependencyGraph
    # Directed acyclic graph for dependency resolution
    class Graph
      # @return [Hash] the adjacency list (item => dependencies)
      attr_reader :nodes

      def initialize
        @nodes = {}
      end

      # Add an item with its dependencies
      #
      # @param item [Object] the item to add
      # @param depends_on [Array] the items this item depends on
      # @return [self]
      def add(item, depends_on: [])
        @nodes[item] ||= []
        depends_on.each do |dep|
          @nodes[dep] ||= []
          @nodes[item] << dep unless @nodes[item].include?(dep)
        end
        self
      end

      # Resolve dependencies using topological sort (Kahn's algorithm)
      #
      # @return [Array] items in dependency order (dependencies first)
      # @raise [Error] if a cycle is detected
      def resolve
        raise Error, "Cycle detected: #{cycles.first.join(' -> ')}" if cycle?

        in_degree = Hash.new(0)
        @nodes.each_key { |node| in_degree[node] ||= 0 }
        @nodes.each_value do |deps|
          deps.each { |dep| in_degree[dep] += 1 }
        end

        queue = @nodes.keys.select { |node| in_degree[node].zero? }
        result = []

        until queue.empty?
          node = queue.shift
          result << node
          @nodes[node].each do |dep|
            in_degree[dep] -= 1
            queue << dep if in_degree[dep].zero?
          end
        end

        result.reverse
      end

      # Group items into parallel execution batches
      #
      # @return [Array<Array>] batches where items in each batch can run in parallel
      # @raise [Error] if a cycle is detected
      def parallel_batches
        raise Error, "Cycle detected: #{cycles.first.join(' -> ')}" if cycle?

        remaining = @nodes.keys.dup
        resolved = []
        batches = []

        until remaining.empty?
          batch = remaining.select do |item|
            @nodes[item].all? { |dep| resolved.include?(dep) }
          end

          raise Error, 'Unable to resolve dependencies' if batch.empty?

          batches << batch
          resolved.concat(batch)
          remaining -= batch
        end

        batches
      end

      # Check if the graph contains any cycles
      #
      # @return [Boolean]
      def cycle?
        !cycles.empty?
      end

      # Find all cycles in the graph
      #
      # @return [Array<Array>] list of cycles, each cycle is an array of items
      def cycles
        found_cycles = []
        visited = {}
        stack = {}

        @nodes.each_key do |node|
          next if visited[node]

          detect_cycles(node, visited, stack, [], found_cycles)
        end

        found_cycles
      end

      private

      def detect_cycles(node, visited, stack, path, found_cycles)
        visited[node] = true
        stack[node] = true
        path = path + [node]

        @nodes[node]&.each do |dep|
          if stack[dep]
            cycle_start = path.index(dep)
            found_cycles << path[cycle_start..] + [dep] if cycle_start
          elsif !visited[dep]
            detect_cycles(dep, visited, stack, path, found_cycles)
          end
        end

        stack.delete(node)
      end
    end
  end
end
