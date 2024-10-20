# frozen_string_literal: true

require 'spec_helper'
require './lib/node'

describe Node do
  before(:each) do
    @nodes = generate_cluster %w[Jake Maria Jose]
  end

  describe 'Leader election' do
    context 'when all the nodes are followers and the maximum heartbeat timeout has passed' do
      it 'a single leader is elected' do
        simulate_cluster(@nodes) do |_nodes|
          sleep Node::MAX_HEARTBEAT_TIMEOUT
        end

        expected_node_roles = %i[leader follower follower]
        node_roles = @nodes.map(&:role)

        expect(node_roles.sort).to eq expected_node_roles.sort
      end
    end
  end

  describe 'State proposal' do
    context 'No failures' do
      context 'the leader receives a state proposal' do
        it 'propagates the state accordinly' do
          state = 'some state'

          simulate_cluster(@nodes) do |nodes|
            sleep Node::MAX_HEARTBEAT_TIMEOUT

            leader = nodes.detect(&:leader?)
            leader.propose_state(state)

            sleep Node::HEARTBEAT_INTERVAL
          end

          expect(@nodes.map(&:log)).to eq Array.new @nodes.count, [state]
        end
      end

      context 'a follower receives a state proposal' do
        it 'fowards the proposal to the leader' do
          state = 'some state'

          simulate_cluster(@nodes) do |nodes|
            sleep Node::MAX_HEARTBEAT_TIMEOUT

            follower = nodes.detect(&:follower?)
            follower.propose_state(state)

            sleep Node::HEARTBEAT_INTERVAL
          end

          leader = @nodes.detect(&:leader?)
          got_state_proposal = leader.inbox_log.any? { |message| message[:type] = :propose_state }

          expect(got_state_proposal).to be true
        end
      end
    end
  end
end
