# frozen_string_literal: true

require 'rake'

task :run do
  require_relative 'lib/node'

  node_names = %w[Jake Maria Jose]
  nodes = node_names.map { |name| Node.new name }
  nodes.each do |node|
    neighbors = nodes.reject { |neighbor| node == neighbor }
    neighbors.each do |neighbor|
      node.add_neighbor neighbor
    end
  end

  leader = nodes.first.tap(&:become_leader)
  simulation_thread = Thread.new do
    sleep 1
    leader.become_follower
  end

  nodes.each(&:start)
  nodes.each(&:join)
  simulation_thread.join
end
