# frozen_string_literal: true

require 'spec_helper'
require './lib/node'

describe Node do
  describe '::add_neighbor' do
    before(:each) do
      @node = Node.new 'node'
      @neighbor = Node.new 'neighbor'
    end

    it 'adds a neighbor' do
      @node.add_neighbor @neighbor

      expect(@node.neighbors).to include(@neighbor)
    end

    it 'doesnt add a node as a neighbor of itself' do
      @node.add_neighbor @node

      expect(@node.neighbors).not_to include(@node)
    end
  end

  describe '::remove_neighbor' do
    before(:each) do
      @node = Node.new 'node'
      @neighbor = Node.new 'neighbor'
      @node.add_neighbor @neighbor
    end

    it 'removes a neighbor' do
      @node.remove_neighbor @neighbor

      expect(@node.neighbors).not_to include(@neighbor)
    end

    it 'doesnt remove node if it isnt a neighbor' do
      other_node = Node.new "other"
      @node.remove_neighbor other_node

      expect(@node.neighbors).to include(@neighbor)
    end
  end

  describe '::simulate_partition' do
    context 'In a cluster of nodes all connected to each other' do
      before(:each) do
        @node1, @node2, @node3 = generate_cluster %w[node1 node2 node3]
      end

      it 'disconnects a single node from the rest' do
        @node1.simulate_partition [@node3]

        expect(@node1.neighbors).not_to include(@node3)
        expect(@node2.neighbors).not_to include(@node3)
        expect(@node3.neighbors).not_to include([@node1, @node2])
      end

      it 'disconnects multiple nodes from the rest' do
        @node1.simulate_partition [@node2, @node3]

        expect(@node1.neighbors).not_to include([@node2, @node3])

        expect(@node2.neighbors).to include(@node3)
        expect(@node2.neighbors).not_to include(@node1)

        expect(@node3.neighbors).to include(@node2)
        expect(@node3.neighbors).not_to include(@node1)
      end

      it 'cannot disconnect a node from it self'
    end
  end

  describe '::propose_state' do
    context 'A partition occurs' do
      before(:each) do
        @nodes = generate_cluster %w[node1 node2 node3]
      end

      it 'propagates the state accordinly' do
        start_cluster(@nodes) do |nodes|
          node1, node2, node3 = nodes

          node1.propose_state(1)
          node2.propose_state(2)
          node3.simulate_partition([node1])
          node2.propose_state(3)
        end

        node1, node2, node3 = @nodes

        expect(node1.retrieve_log).to eq [1, 2]
        expect(node2.retrieve_log).to eq [1, 2, 3]
        expect(node3.retrieve_log).to eq [1, 2, 3]
      end
    end
  end
end
