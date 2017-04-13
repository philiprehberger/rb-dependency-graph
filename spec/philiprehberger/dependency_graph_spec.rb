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
  end
end
