# frozen_string_literal: true

require 'spec_helper'
require './lib/node'

describe Node do
  describe 'Leader election' do
    before(:all) do
      node_names = %w[Jake Maria Jose]
      @nodes = node_names.map { |name| Node.new name }
      @nodes.each do |node|
        neighbors = @nodes.reject { |neighbor| node == neighbor }
        neighbors.each do |neighbor|
          node.add_neighbor neighbor
        end
      end
      @nodes.each(&:start)

      simulation_thread = Thread.new do
        # Wait for the nodes to elect a leader
        sleep Node::MAX_HEARTBEAT_TIMEOUT
      ensure
        @nodes.each(&:stop)
      end

      @nodes.each(&:join)
      simulation_thread.join
    end

    context 'when all the nodes are followers and the maximum heartbeat timeout has passed' do
      it 'a single leader is elected' do
        expected_node_roles = Set.new(%i[leader follower follower])
        node_roles = Set.new(@nodes.map(&:role))

        expect(node_roles).to eq(expected_node_roles)
      end
    end
  end
end
