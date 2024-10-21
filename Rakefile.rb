# frozen_string_literal: true

require 'rake'

task :debug do
  require './lib/node'
  require './spec/helpers'
  include Helpers

  nodes = generate_cluster %w[Jake Maria Jose]

  start_cluster(nodes) do |nodes|
    ['state1', 'state2', 'state3'].each do |state|
      nodes.sample.propose_state state
    end
  end

  nodes.each do |node|
    puts "#{node.name}'s log:"
    puts "\tState log: #{node.log}"
    puts "\tInbox log:"
    node.inbox_log.each { |message| puts "\t\t#{message}" }
  end

  binding.irb
end
