# frozen_string_literal: true

require 'rake'

task :debug do
  require './lib/node'
  require './spec/helpers'
  include Helpers

  nodes = generate_cluster %w[Jake Maria Jose]

  start_cluster(nodes) do |nodes|
    node1, node2, node3 = nodes

    node1.propose_state(1)
    node2.propose_state(2)
    node2.propose_state(3)
  end

  nodes.each do |node|
    puts "#{node.name}'s log:"
    puts "\tState log: #{node.log}"
    puts "\tInbox log:"
    node.inbox_log.each { |message| puts "\t\t#{message}" }
  end

  binding.irb
end
