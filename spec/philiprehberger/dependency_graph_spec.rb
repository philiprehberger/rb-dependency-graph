# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::DependencyGraph do
  it 'has a version number' do
    expect(described_class::VERSION).not_to be_nil
  end

  describe '.new' do
    it 'creates a new Graph' do
      graph = described_class.new
      expect(graph).to be_a(described_class::Graph)
    end
  end

  describe Philiprehberger::DependencyGraph::Graph do
    let(:graph) { described_class.new }

    describe '#add' do
      it 'adds an item without dependencies' do
        graph.add(:a)
        expect(graph.nodes).to have_key(:a)
      end

      it 'adds an item with dependencies' do
        graph.add(:b, depends_on: [:a])
        expect(graph.nodes[:b]).to include(:a)
      end

      it 'auto-creates dependency nodes' do
        graph.add(:b, depends_on: [:a])
        expect(graph.nodes).to have_key(:a)
      end

      it 'does not duplicate dependencies' do
        graph.add(:b, depends_on: [:a])
        graph.add(:b, depends_on: [:a])
        expect(graph.nodes[:b].count(:a)).to eq(1)
      end

      it 'returns self for chaining' do
        result = graph.add(:a)
        expect(result).to eq(graph)
      end
    end

    describe '#resolve' do
      it 'resolves a simple chain' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:b])

        result = graph.resolve
        expect(result.index(:a)).to be < result.index(:b)
        expect(result.index(:b)).to be < result.index(:c)
      end

      it 'resolves independent items' do
        graph.add(:a)
        graph.add(:b)
        graph.add(:c)

        result = graph.resolve
        expect(result.size).to eq(3)
      end

      it 'resolves diamond dependencies' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:a])
        graph.add(:d, depends_on: %i[b c])

        result = graph.resolve
        expect(result.index(:a)).to be < result.index(:b)
        expect(result.index(:a)).to be < result.index(:c)
        expect(result.index(:b)).to be < result.index(:d)
        expect(result.index(:c)).to be < result.index(:d)
      end

      it 'raises Error on cycle' do
        graph.add(:a, depends_on: [:b])
        graph.add(:b, depends_on: [:a])

        expect { graph.resolve }.to raise_error(described_class::Error, /Cycle detected/)
      end
    end

    describe '#parallel_batches' do
      it 'groups independent items in one batch' do
        graph.add(:a)
        graph.add(:b)
        graph.add(:c)

        batches = graph.parallel_batches
        expect(batches.size).to eq(1)
        expect(batches.first).to contain_exactly(:a, :b, :c)
      end

      it 'separates dependent items into sequential batches' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:b])

        batches = graph.parallel_batches
        expect(batches.size).to eq(3)
        expect(batches[0]).to eq([:a])
        expect(batches[1]).to eq([:b])
        expect(batches[2]).to eq([:c])
      end

      it 'groups parallelizable items in diamond dependency' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:a])
        graph.add(:d, depends_on: %i[b c])

        batches = graph.parallel_batches
        expect(batches.size).to eq(3)
        expect(batches[0]).to eq([:a])
        expect(batches[1]).to contain_exactly(:b, :c)
        expect(batches[2]).to eq([:d])
      end

      it 'raises Error on cycle' do
        graph.add(:a, depends_on: [:b])
        graph.add(:b, depends_on: [:a])

        expect { graph.parallel_batches }.to raise_error(described_class::Error, /Cycle detected/)
      end
    end

    describe '#cycle?' do
      it 'returns false for acyclic graph' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])

        expect(graph.cycle?).to be false
      end

      it 'returns true for cyclic graph' do
        graph.add(:a, depends_on: [:b])
        graph.add(:b, depends_on: [:a])

        expect(graph.cycle?).to be true
      end

      it 'detects transitive cycles' do
        graph.add(:a, depends_on: [:c])
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:b])

        expect(graph.cycle?).to be true
      end
    end

    describe '#cycles' do
      it 'returns empty array for acyclic graph' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])

        expect(graph.cycles).to be_empty
      end

      it 'returns cycle paths for cyclic graph' do
        graph.add(:a, depends_on: [:b])
        graph.add(:b, depends_on: [:a])

        cycles = graph.cycles
        expect(cycles).not_to be_empty
        expect(cycles.first.size).to be >= 2
      end
    end

    describe '#dependencies_of' do
      it 'returns direct dependencies' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: %i[a b])

        expect(graph.dependencies_of(:c)).to contain_exactly(:a, :b)
      end

      it 'returns empty array for a node with no dependencies' do
        graph.add(:a)
        expect(graph.dependencies_of(:a)).to eq([])
      end

      it 'returns empty array for an unknown node' do
        expect(graph.dependencies_of(:unknown)).to eq([])
      end
    end

    describe '#all_dependencies_of' do
      it 'returns all transitive dependencies' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:b])

        expect(graph.all_dependencies_of(:c)).to contain_exactly(:a, :b)
      end

      it 'returns only direct dependencies when there are no transitive ones' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])

        expect(graph.all_dependencies_of(:b)).to eq([:a])
      end

      it 'returns empty array for a root node' do
        graph.add(:a)
        expect(graph.all_dependencies_of(:a)).to eq([])
      end

      it 'returns empty array for an unknown node' do
        expect(graph.all_dependencies_of(:unknown)).to eq([])
      end

      it 'handles diamond dependencies without duplicates' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:a])
        graph.add(:d, depends_on: %i[b c])

        expect(graph.all_dependencies_of(:d)).to contain_exactly(:a, :b, :c)
      end
    end

    describe '#dependents_of' do
      it 'returns direct dependents' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:a])

        expect(graph.dependents_of(:a)).to contain_exactly(:b, :c)
      end

      it 'returns empty array for a leaf node' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])

        expect(graph.dependents_of(:b)).to eq([])
      end

      it 'returns empty array for an unknown node' do
        expect(graph.dependents_of(:unknown)).to eq([])
      end
    end

    describe '#path' do
      it 'finds shortest path between two nodes' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:b])

        expect(graph.path(:c, :a)).to eq(%i[c b a])
      end

      it 'returns single-element array when from equals to' do
        graph.add(:a)
        expect(graph.path(:a, :a)).to eq([:a])
      end

      it 'returns nil when no path exists' do
        graph.add(:a)
        graph.add(:b)

        expect(graph.path(:a, :b)).to be_nil
      end

      it 'returns nil for unknown nodes' do
        expect(graph.path(:unknown, :other)).to be_nil
      end

      it 'finds shortest path in diamond graph' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:a])
        graph.add(:d, depends_on: %i[b c])

        path = graph.path(:d, :a)
        expect(path.first).to eq(:d)
        expect(path.last).to eq(:a)
        expect(path.length).to eq(3)
      end
    end

    describe '#subgraph' do
      it 'extracts a subgraph with selected nodes' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:b])
        graph.add(:d, depends_on: [:c])

        sub = graph.subgraph(:a, :b, :c)
        expect(sub.nodes.keys).to contain_exactly(:a, :b, :c)
        expect(sub.dependencies_of(:c)).to eq([:b])
        expect(sub.dependencies_of(:b)).to eq([:a])
      end

      it 'excludes edges to nodes not in the subgraph' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:b])

        sub = graph.subgraph(:b, :c)
        expect(sub.dependencies_of(:b)).to eq([])
        expect(sub.dependencies_of(:c)).to eq([:b])
      end

      it 'returns empty graph for unknown nodes' do
        sub = graph.subgraph(:unknown)
        expect(sub.nodes).to be_empty
      end

      it 'accepts an array of items' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])

        sub = graph.subgraph(%i[a b])
        expect(sub.nodes.keys).to contain_exactly(:a, :b)
      end
    end

    describe '#roots' do
      it 'returns nodes with no dependencies' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c)

        expect(graph.roots).to contain_exactly(:a, :c)
      end

      it 'returns empty array for empty graph' do
        expect(graph.roots).to eq([])
      end

      it 'returns all nodes when none have dependencies' do
        graph.add(:a)
        graph.add(:b)

        expect(graph.roots).to contain_exactly(:a, :b)
      end
    end

    describe '#leaves' do
      it 'returns nodes that no other node depends on' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:a])

        expect(graph.leaves).to contain_exactly(:b, :c)
      end

      it 'returns empty array for empty graph' do
        expect(graph.leaves).to eq([])
      end

      it 'returns all nodes when there are no edges' do
        graph.add(:a)
        graph.add(:b)

        expect(graph.leaves).to contain_exactly(:a, :b)
      end
    end

    describe '#depth' do
      it 'returns 0 for a root node' do
        graph.add(:a)
        expect(graph.depth(:a)).to eq(0)
      end

      it 'returns 1 for a direct dependent of a root' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])

        expect(graph.depth(:b)).to eq(1)
      end

      it 'returns max depth for deep chains' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:b])
        graph.add(:d, depends_on: [:c])

        expect(graph.depth(:d)).to eq(3)
      end

      it 'returns max depth in diamond graph' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:a])
        graph.add(:d, depends_on: %i[b c])

        expect(graph.depth(:d)).to eq(2)
      end

      it 'returns 0 for an unknown node' do
        expect(graph.depth(:unknown)).to eq(0)
      end

      it 'handles disconnected nodes' do
        graph.add(:a)
        graph.add(:b)

        expect(graph.depth(:a)).to eq(0)
        expect(graph.depth(:b)).to eq(0)
      end
    end

    describe '#merge' do
      it 'merges nodes and dependencies from another graph' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])

        other = described_class.new
        other.add(:c, depends_on: [:b])
        other.add(:d, depends_on: [:c])

        graph.merge(other)
        expect(graph.nodes.keys).to contain_exactly(:a, :b, :c, :d)
        expect(graph.dependencies_of(:c)).to eq([:b])
      end

      it 'combines duplicate dependencies without duplication' do
        graph.add(:b, depends_on: [:a])
        other = described_class.new
        other.add(:b, depends_on: [:a])
        graph.merge(other)
        expect(graph.nodes[:b]).to eq([:a])
      end

      it 'returns self for chaining' do
        other = described_class.new
        expect(graph.merge(other)).to eq(graph)
      end

      it 'raises Error for non-Graph argument' do
        expect { graph.merge('not a graph') }.to raise_error(described_class::Error)
      end
    end

    describe '#remove' do
      it 'removes a node and all edges referencing it' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:a])

        expect(graph.remove(:a)).to be true
        expect(graph.nodes).not_to have_key(:a)
        expect(graph.dependencies_of(:b)).to eq([])
        expect(graph.dependencies_of(:c)).to eq([])
      end

      it 'returns false for unknown nodes' do
        expect(graph.remove(:unknown)).to be false
      end
    end

    describe '#size and #empty?' do
      it 'reports size and empty correctly' do
        expect(graph.empty?).to be true
        expect(graph.size).to eq(0)
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        expect(graph.empty?).to be false
        expect(graph.size).to eq(2)
      end
    end

    describe '#to_dot' do
      it 'emits a valid Graphviz digraph' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])

        dot = graph.to_dot
        expect(dot).to start_with('digraph G {')
        expect(dot).to end_with('}')
        expect(dot).to include('"a"')
        expect(dot).to include('"b"')
        expect(dot).to include('"b" -> "a"')
      end

      it 'accepts a custom graph name' do
        graph.add(:a)
        expect(graph.to_dot(name: 'Deps')).to include('digraph Deps {')
      end

      it 'emits empty digraph for empty graph' do
        expect(graph.to_dot).to eq("digraph G {\n}")
      end

      it 'escapes quotes in node labels' do
        graph.add('a"b')
        expect(graph.to_dot).to include('"a\\"b"')
      end
    end

    describe 'edge cases' do
      it 'handles an empty graph' do
        expect(graph.nodes).to be_empty
        expect(graph.resolve).to eq([])
        expect(graph.cycle?).to be false
        expect(graph.cycles).to be_empty
      end

      it 'handles a single node with no dependencies' do
        graph.add(:only)
        expect(graph.resolve).to eq([:only])
        expect(graph.parallel_batches).to eq([[:only]])
      end

      it 'handles a single node depending on itself (self-cycle)' do
        graph.add(:a, depends_on: [:a])
        expect(graph.cycle?).to be true
      end

      it 'handles adding the same node multiple times without dependencies' do
        graph.add(:a)
        graph.add(:a)
        expect(graph.nodes.keys.count(:a)).to eq(1)
      end

      it 'handles adding multiple dependencies in one call' do
        graph.add(:d, depends_on: %i[a b c])
        expect(graph.nodes[:d]).to contain_exactly(:a, :b, :c)
      end

      it 'resolves disconnected components' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:x)
        graph.add(:y, depends_on: [:x])

        result = graph.resolve
        expect(result.index(:a)).to be < result.index(:b)
        expect(result.index(:x)).to be < result.index(:y)
        expect(result.size).to eq(4)
      end

      it 'produces correct parallel batches for disconnected components' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:x)
        graph.add(:y, depends_on: [:x])

        batches = graph.parallel_batches
        expect(batches.first).to contain_exactly(:a, :x)
        expect(batches[1]).to contain_exactly(:b, :y)
      end

      it 'handles long chains' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:b])
        graph.add(:d, depends_on: [:c])
        graph.add(:e, depends_on: [:d])

        result = graph.resolve
        expect(result).to eq(%i[a b c d e])
      end

      it 'handles string keys' do
        graph.add('web', depends_on: ['db'])
        graph.add('db')

        result = graph.resolve
        expect(result.index('db')).to be < result.index('web')
      end

      it 'handles integer keys' do
        graph.add(1)
        graph.add(2, depends_on: [1])

        result = graph.resolve
        expect(result).to eq([1, 2])
      end

      it 'detects a three-node cycle' do
        graph.add(:a, depends_on: [:b])
        graph.add(:b, depends_on: [:c])
        graph.add(:c, depends_on: [:a])

        expect(graph.cycle?).to be true
        expect { graph.resolve }.to raise_error(described_class::Error, /Cycle detected/)
      end

      it 'parallel_batches returns empty for empty graph' do
        expect(graph.parallel_batches).to eq([])
      end

      it 'supports chaining add calls' do
        graph.add(:a).add(:b, depends_on: [:a]).add(:c, depends_on: [:b])
        result = graph.resolve
        expect(result).to eq(%i[a b c])
      end
    end

    describe '#reverse' do
      it 'returns a new graph with edges flipped' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:b])

        reversed = graph.reverse
        expect(reversed).to be_a(described_class)
        expect(reversed).not_to equal(graph)
        expect(reversed.dependencies_of(:a)).to eq([:b])
        expect(reversed.dependencies_of(:b)).to eq([:c])
        expect(reversed.dependencies_of(:c)).to eq([])
      end

      it 'preserves all nodes including isolated ones' do
        graph.add(:a)
        graph.add(:b)
        reversed = graph.reverse
        expect(reversed.size).to eq(2)
      end

      it 'does not mutate the original graph' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.reverse
        expect(graph.dependencies_of(:b)).to eq([:a])
        expect(graph.dependencies_of(:a)).to eq([])
      end

      it 'reverse of reverse yields equivalent edges' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: %i[a b])

        round_trip = graph.reverse.reverse
        graph.nodes.each_key do |node|
          expect(round_trip.dependencies_of(node).sort).to eq(graph.dependencies_of(node).sort)
        end
      end
    end

    describe '#all_dependents_of' do
      it 'returns transitive dependents' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:b])
        graph.add(:d, depends_on: [:c])

        expect(graph.all_dependents_of(:a)).to contain_exactly(:b, :c, :d)
        expect(graph.all_dependents_of(:b)).to contain_exactly(:c, :d)
        expect(graph.all_dependents_of(:d)).to eq([])
      end

      it 'returns empty array for unknown item' do
        expect(graph.all_dependents_of(:missing)).to eq([])
      end

      it 'handles diamond dependencies without duplicates' do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c, depends_on: [:a])
        graph.add(:d, depends_on: %i[b c])

        expect(graph.all_dependents_of(:a)).to contain_exactly(:b, :c, :d)
      end
    end

    describe '#independent?' do
      before do
        graph.add(:a)
        graph.add(:b, depends_on: [:a])
        graph.add(:c)
        graph.add(:d, depends_on: [:c])
      end

      it 'returns true for two unrelated nodes' do
        expect(graph.independent?(:b, :d)).to be true
        expect(graph.independent?(:a, :c)).to be true
      end

      it 'returns false when one depends on the other' do
        expect(graph.independent?(:a, :b)).to be false
        expect(graph.independent?(:b, :a)).to be false
      end

      it 'returns false for the same node' do
        expect(graph.independent?(:a, :a)).to be false
      end

      it 'returns false if either node is unknown' do
        expect(graph.independent?(:a, :missing)).to be false
        expect(graph.independent?(:missing, :a)).to be false
      end

      it 'detects transitive dependency as not independent' do
        graph.add(:e, depends_on: [:b])
        expect(graph.independent?(:e, :a)).to be false
      end
    end
  end
end
