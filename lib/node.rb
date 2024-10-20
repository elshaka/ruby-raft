# frozen_string_literal: true

require 'securerandom'
require './lib/raft'

class Node
  attr_reader :uuid, :name, :log, :inbox, :inbox_log

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

  def remove_neighbor(node)
    @neighbors.delete(node)
  end

  def neighbors_count
    @neighbors.count
  end

  def propose_state(state)
    send(self, :propose_state, state)
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
end
