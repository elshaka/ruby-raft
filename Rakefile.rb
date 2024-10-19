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
  nodes.each(&:start)

  simulation_thread = Thread.new do
    %w[hello how are you].each do |state|
      nodes.last.propose_state(state)
      sleep 1
    end
    leader.kill
  end

  nodes.each(&:join)
  simulation_thread.join

  nodes.each do |node|
    puts "#{node.name}'s log:"
    puts "\tState log: #{node.log}"
    puts "\tInbox log:"
    node.inbox_log.each { |message| puts "\t\t#{message}" }
  end

  binding.irb
end
