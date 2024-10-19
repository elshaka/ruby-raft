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
    ['hello', 'how', 'are', 'you'].each do |state|
      nodes.last.propose_state(state)
      sleep 0.5
    end
    leader.kill
  end

  nodes.each(&:start)
  nodes.each(&:join)

  nodes.each do |node|
    puts "#{node.name}'s log: #{node.log}"
  end

  simulation_thread.join
end
