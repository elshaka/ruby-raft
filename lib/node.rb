# frozen_string_literal: true

require 'securerandom'
require './lib/raft'

class Node
  OPERATION_SLEEP_TIME = 1

  attr_reader :name, :neighbors, :log, :inbox, :inbox_log

  def initialize(name)
    @name = name
    @uuid = SecureRandom.uuid
    @status = :stopped
    @neighbors = Set.new
    @inbox = []
    @inbox_log = []
    @log = []
    @algorithm = Raft.new self
  end

  def add_neighbor(node)
    @neighbors << node
  end

  def propose_state(state)
    send(self, :propose_state, state)
    sleep OPERATION_SLEEP_TIME
  end

  def simulate_partition(nodes)
    puts "The following nodes will be disconected from #{name} and its neighbors: #{nodes}"
    nodes.each do |node|
      remove_neighbor(node)
      node.remove_neighbor(self)
    end
    sleep OPERATION_SLEEP_TIME
  end

  def retrieve_log
    @log
  end

  def remove_neighbor(node)
    @neighbors.delete(node)
  end

  def start
    @status = :running
    @algorithm.start
    puts "Node #{name} has been started"
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

  def role
    @algorithm.role
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
