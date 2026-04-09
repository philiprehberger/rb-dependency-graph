# frozen_string_literal: true

module Philiprehberger
  module DependencyGraph
    # Directed acyclic graph for dependency resolution
    class Graph
      Error = DependencyGraph::Error

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

      # Return direct dependencies of an item
      #
      # @param item [Object] the item to query
      # @return [Array] direct dependencies, or empty array if item is unknown
      def dependencies_of(item)
        (@nodes[item] || []).dup
      end

      # Return all transitive dependencies of an item (direct + indirect)
      #
      # @param item [Object] the item to query
      # @return [Array] all dependencies in no particular order
      def all_dependencies_of(item)
        return [] unless @nodes.key?(item)

        visited = {}
        queue = @nodes[item].dup
        result = []

        until queue.empty?
          dep = queue.shift
          next if visited[dep]

          visited[dep] = true
          result << dep
          queue.concat(@nodes[dep] || [])
        end

        result
      end

      # Return items that directly depend on the given item (reverse lookup)
      #
      # @param item [Object] the item to query
      # @return [Array] direct dependents
      def dependents_of(item)
        @nodes.each_with_object([]) do |(node, deps), acc|
          acc << node if deps.include?(item)
        end
      end

      # Find shortest dependency path between two nodes using BFS
      #
      # @param from [Object] the starting node
      # @param to [Object] the target node
      # @return [Array, nil] array of nodes forming the path, or nil if no path exists
      def path(from, to)
        return nil unless @nodes.key?(from) && @nodes.key?(to)
        return [from] if from == to

        visited = { from => nil }
        queue = [from]

        until queue.empty?
          current = queue.shift
          (@nodes[current] || []).each do |dep|
            next if visited.key?(dep)

            visited[dep] = current
            if dep == to
              return build_path(visited, from, to)
            end

            queue << dep
          end
        end

        nil
      end

      # Extract a subgraph containing only the specified nodes and edges between them
      #
      # @param items [Array<Object>] nodes to include
      # @return [Graph] a new graph with only the specified nodes
      def subgraph(*items)
        item_set = items.flatten.to_h { |i| [i, true] }
        new_graph = self.class.new

        items.flatten.each do |item|
          next unless @nodes.key?(item)

          matching_deps = (@nodes[item] || []).select { |dep| item_set[dep] }
          new_graph.add(item, depends_on: matching_deps)
        end

        new_graph
      end

      # Return nodes that have no dependencies
      #
      # @return [Array] root nodes
      def roots
        @nodes.select { |_node, deps| deps.empty? }.keys
      end

      # Return nodes with no dependents (no other node depends on them)
      #
      # @return [Array] leaf nodes
      def leaves
        depended_on = @nodes.values.flatten.uniq
        @nodes.keys.reject { |node| depended_on.include?(node) }
      end

      # Merge another graph into this one, combining nodes and dependencies
      #
      # @param other [Graph] another graph to merge
      # @return [self]
      def merge(other)
        raise Error, 'Can only merge Graph instances' unless other.is_a?(self.class)

        other.nodes.each do |node, deps|
          @nodes[node] ||= []
          deps.each do |dep|
            @nodes[node] << dep unless @nodes[node].include?(dep)
          end
        end
        self
      end

      # Remove a node and all edges referencing it
      #
      # @param item [Object] the item to remove
      # @return [Boolean] true if the node existed, false otherwise
      def remove(item)
        return false unless @nodes.key?(item)

        @nodes.delete(item)
        @nodes.each_value { |deps| deps.delete(item) }
        true
      end

      # Total number of nodes in the graph
      #
      # @return [Integer]
      def size
        @nodes.size
      end

      # Whether the graph has no nodes
      #
      # @return [Boolean]
      def empty?
        @nodes.empty?
      end

      # Return a new graph with all edges reversed (dependents become dependencies)
      #
      # @return [Graph] a new graph where each edge direction is flipped
      def reverse
        new_graph = self.class.new
        @nodes.each_key { |node| new_graph.instance_variable_get(:@nodes)[node] ||= [] }
        @nodes.each do |node, deps|
          deps.each { |dep| new_graph.add(dep, depends_on: [node]) }
        end
        new_graph
      end

      # Return all transitive dependents of an item (direct + indirect)
      #
      # @param item [Object] the item to query
      # @return [Array] all items that depend on this item, directly or transitively
      def all_dependents_of(item)
        return [] unless @nodes.key?(item)

        visited = {}
        queue = dependents_of(item)
        result = []

        until queue.empty?
          dep = queue.shift
          next if visited[dep]

          visited[dep] = true
          result << dep
          queue.concat(dependents_of(dep))
        end

        result
      end

      # Check whether two nodes are independent (neither depends on the other transitively)
      #
      # @param node_a [Object]
      # @param node_b [Object]
      # @return [Boolean] true if neither node is reachable from the other
      def independent?(node_a, node_b)
        return false if node_a == node_b
        return false unless @nodes.key?(node_a) && @nodes.key?(node_b)

        !all_dependencies_of(node_a).include?(node_b) &&
          !all_dependencies_of(node_b).include?(node_a)
      end

      # Export the graph in Graphviz DOT format
      #
      # @param name [String] the digraph name
      # @return [String] DOT source
      def to_dot(name: 'G')
        lines = ["digraph #{name} {"]
        @nodes.each_key { |node| lines << "  #{dot_quote(node)};" }
        @nodes.each do |node, deps|
          deps.each { |dep| lines << "  #{dot_quote(node)} -> #{dot_quote(dep)};" }
        end
        lines << '}'
        lines.join("\n")
      end

      # Calculate maximum dependency depth for a node (longest path from any root to this node)
      #
      # @param item [Object] the item to query
      # @return [Integer] the depth, or 0 if the item is a root or unknown
      def depth(item)
        return 0 unless @nodes.key?(item)

        memo = {}
        compute_depth(item, memo)
      end

      private

      def dot_quote(node)
        %("#{node.to_s.gsub('"', '\"')}")
      end

      def build_path(visited, from, to)
        path = [to]
        current = to
        while current != from
          current = visited[current]
          path.unshift(current)
        end
        path
      end

      def compute_depth(item, memo)
        return memo[item] if memo.key?(item)

        deps = @nodes[item] || []
        memo[item] = if deps.empty?
                       0
                     else
                       deps.map { |dep| compute_depth(dep, memo) }.max + 1
                     end

        memo[item]
      end

      def detect_cycles(node, visited, stack, path, found_cycles)
        visited[node] = true
        stack[node] = true
        path += [node]

        @nodes[node]&.each do |dep|
          if stack[dep]
            cycle_start = path.index(dep)
            found_cycles << (path[cycle_start..] + [dep]) if cycle_start
          elsif !visited[dep]
            detect_cycles(dep, visited, stack, path, found_cycles)
          end
        end

        stack.delete(node)
      end
    end
  end
end
