# frozen_string_literal: true

require 'spec_helper'
require './lib/node'

describe Node do
  before(:each) do
    @nodes = generate_cluster %w[Jake Maria Jose]
  end

  describe 'State proposal' do
    context 'No failures' do
      it 'propagates the state accordinly' do
        states = %w[three different states]

        simulate_cluster(@nodes) do |nodes|
          sleep Raft::MAX_HEARTBEAT_TIMEOUT

          states.each do |state|
            nodes.first.propose_state(state)
            sleep Raft::HEARTBEAT_TIMEOUT
          end

          sleep Raft::HEARTBEAT_TIMEOUT
        end

        expect(@nodes.map(&:log)).to eq Array.new @nodes.count, states
      end
    end
  end
end
