# frozen_string_literal: true

require 'securerandom'
require './lib/raft'

class Node
  attr_reader :name, :neighbors, :log, :inbox, :inbox_log

  def initialize(name)
    @name = name
    @uuid = SecureRandom.uuid
    @status = :stopped
    @neighbors = Set.new
    @inbox = Queue.new
    @inbox_log = []
    @log = []
    @algorithm = Raft.new self
  end

  def add_neighbor(node)
    @neighbors << node unless node == self
  end

  def propose_state(state)
    send(self, :propose_state, state)
    sleep operation_sleep_time
  end

  def simulate_partition(nodes_to_partition)
    puts "The following nodes: #{nodes_to_partition.map(&:name)} will be partitioned from: #{cluster.map(&:name)}"
    remaining_nodes = cluster.subtract(nodes_to_partition)

    update_neighbors remaining_nodes
    neighbors.each { |node| node.update_neighbors remaining_nodes }
    nodes_to_partition.each { |node| node.update_neighbors nodes_to_partition }

    sleep operation_sleep_time * 10
  end

  def retrieve_log
    @log
  end

  def remove_neighbor(node)
    @neighbors.delete(node)
  end

  def cluster
    Set.new([self]) + neighbors
  end

  def update_neighbors(new_neighbors)
    @neighbors = Set.new
    new_neighbors.each do |neighbor|
      add_neighbor neighbor
    end
  end

  def start
    @status = :running
    @algorithm.start
    puts "#{name} has been started"
  end

  def stop
    @neighbors.each do |node|
      node.remove_neighbor self
    end
    @neighbors = Set.new
    @status = :stopped
    puts "#{name} is stopping..."
  end

  def send(sender, type, content = nil)
    @inbox << { sender: sender, type: type, content: content } if running?
  end

  def send_to_all_neighbors(type, content = nil)
    @neighbors.each do |node|
      node.send self, type, content
    end
  end

  def max_init_time
    @algorithm.max_init_time
  end

  def operation_sleep_time
    max_init_time / 5
  end

  def join
    @algorithm.join
  end

  def running?
    @status == :running
  end

  def inspect
    "<Node:#{name}>"
  end
end
