# frozen_string_literal: true

require './lib/raft'

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

  def start_cluster(nodes, &block)
    nodes.each(&:start)

    thread = Thread.new do
      sleep Raft::MAX_HEARTBEAT_TIMEOUT

      block.call(nodes) if block_given?

      sleep Raft::HEARTBEAT_INTERVAL
    ensure
      nodes.each(&:stop)
    end

    nodes.each(&:join)
    thread.join
  end
end
