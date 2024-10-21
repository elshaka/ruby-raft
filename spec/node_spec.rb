# frozen_string_literal: true

require 'spec_helper'
require './lib/node'

describe Node do
  describe '::add_neighbor' do
    it 'adds a neighbor'
    it 'doesnt add a node as a neighbor of itself'
  end

  describe '::remove_neighbor' do
    it 'removes a neighbor'
    it 'doesnt remove node if it isnt a neighbor'
  end

  describe '::simulate_partition' do
    context 'In a cluster of nodes all connected to each other' do
      before(:each) do
        @node1, @node2, @node3 = generate_cluster %w[Jake Maria Jose]
      end

      it 'disconnects a single node from the rest'
      it 'disconnects multiple nodes from the rest'
      it 'cannot disconnect a node from it self'
    end
  end

  describe '::propose_state' do
    context 'A partition occurs' do
      before(:each) do
        @nodes = generate_cluster %w[Jake Maria Jose]
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
