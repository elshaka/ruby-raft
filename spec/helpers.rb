# frozen_string_literal: true

module Helpers
  SIM_WAIT_TIME = 3
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
      sleep nodes.first.max_init_time

      block.call(nodes) if block_given?

      sleep nodes.first.operation_sleep_time
    ensure
      nodes.each(&:stop)
    end

    nodes.each(&:join)
    thread.join
  end
end
