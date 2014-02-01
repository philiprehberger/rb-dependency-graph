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
  end
end
