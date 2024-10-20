# frozen_string_literal: true

require './lib/node'

module Helpers
  def generate_cluster(node_names)
    nodes = node_names.map { |name| Node.new name }
    nodes.each do |node|
      neighbors = nodes.reject { |neighbor| node == neighbor }
      neighbors.each do |neighbor|
        node.add_neighbor neighbor
      end
    end

    nodes
  end

  def simulate_cluster(nodes, &block)
    nodes.each(&:start)

    thread = Thread.new do
      block.call(nodes) if block_given?
    ensure
      nodes.each(&:stop)
    end

    nodes.each(&:join)
    thread.join
  end
end
