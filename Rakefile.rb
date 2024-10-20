# frozen_string_literal: true

require 'rake'

task :run do
  require_relative 'lib/node'

  # This script creates a 'cluster' of nodes, all initially followers.

  # The leader announces its presence by continuously sending heartbeats
  # to the followers but since there's initially no leader sending heartbeats,
  # one follower will eventually time out and initiate a leader election.

  # Each follower has a random timeout, ensuring only one node requests
  # an election at a time (hopefully).

  # A state proposal can be sent to any node. If the node is a follower,
  # it will forward the proposal to its leader. However, if the follower
  # has no leader, any state proposal will be lost.

  node_names = %w[Jake Maria Jose]
  nodes = node_names.map { |name| Node.new name }
  nodes.each do |node|
    neighbors = nodes.reject { |neighbor| node == neighbor }
    neighbors.each do |neighbor|
      node.add_neighbor neighbor
    end
  end

  simulation_thread = Thread.new do
    sleep 10

    follower = nodes.detect(&:follower?)
    %w[hello how are you].each do |state|
      follower.propose_state(state)
      sleep 1
    end

    leader = nodes.detect(&:leader?)
    leader.kill

    sleep 10
    %w[my name is Eleazar].each do |state|
      nodes.last.propose_state(state)
      sleep 1
    end

    nodes.each(&:kill)
  end

  nodes.each(&:join)
  simulation_thread.join

  nodes.each do |node|
    puts "#{node.name}'s log:"
    puts "\tState log: #{node.log}"
    puts "\tInbox log:"
    node.inbox_log.each { |message| puts "\t\t#{message}" }
  end
end
