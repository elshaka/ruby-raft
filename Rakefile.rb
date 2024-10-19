# frozen_string_literal: true

require 'rake'
require 'rubocop/rake_task'

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
  nodes.each(&:hello)

  nodes.each(&:take)
end
