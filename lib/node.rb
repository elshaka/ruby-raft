# frozen_string_literal: true

require 'securerandom'
require 'timeout'

class Node
  HEARTBEAT_INTERVAL = 0.5
  HEARTBEAT_TIMEOUT = HEARTBEAT_INTERVAL + 1

  attr_reader :uuid, :name, :log, :inbox_log
  attr_accessor :leader

  def initialize(name)
    @name = name
    @uuid = SecureRandom.uuid
    @role = :follower
    @status = :alive
    @neighbors = []
    @leader = nil
    @inbox = Queue.new
    @inbox_log = []
    @log = []
  end

  def add_neighbor(node)
    @neighbors << node unless @neighbors.include?(node)
  end

  def start
    @inbox_thread = Thread.new do
      loop do
        break if dead?

        sender, type, content = receive

        @inbox_log << { sender: sender.name, type: type, content: content } unless type == :timeout

        case type
        when :heartbeat
          puts "#{name} received heartbeat from leader #{sender.name}"
        when :propose_state
          if leader?
            puts "#{name} (leader) received a state proposal (#{content})"
            log_state content
            propagate_state content
          else
            puts "#{name} received a state proposal (#{content}) but it's not the leader, fowarding proposal"
            propose_state_to_leader content
          end
        when :log_state
          log_state content
        when :timeout
          unless leader?
            puts "#{name} received no heartbeat, it gon die"
            kill # TODO: Call to elections instead
          end
        else
          puts "#{name} received #{{ sender: sender.name, type: type, content: content }} (unkown message type)"
        end
      end
    end

    @heartbeat_thread = Thread.new do
      loop do
        break if dead?

        heartbeat if leader?
        sleep HEARTBEAT_INTERVAL
      end
    end
  end

  def propose_state(state)
    send(self, :propose_state, state)
  end

  def propose_state_to_leader(state)
    raise "Node #{self} does not have a leader to foward a state proposal" unless @leader

    @leader.send(self, :propose_state, state)
  end

  def propagate_state(state)
    raise "Node #{self} cannot propagate the state #{state} since it's not the leader" unless leader?

    @neighbors.each do |node|
      node.send self, :log_state, state
    end
    puts "State #{state} has been propagated"
  end

  def log_state(content)
    @log << content
  end

  def send(sender, type, content = nil)
    @inbox << [sender, type, content]
  end

  def become_leader
    @role = :leader
    @neighbors.each { |node| node.leader = self }
    puts "#{name} is now the leader"
  end

  def become_follower
    @role = :follower
    puts "#{name} is now a follower"
  end

  def kill
    @status = :dead
    puts "#{name} has been killed"
  end

  def join
    @inbox_thread.join
    @heartbeat_thread.join
  end

  private

  def leader?
    @role == :leader
  end

  def dead?
    @status == :dead
  end

  def receive
    Timeout.timeout(HEARTBEAT_TIMEOUT + 2 * rand) do
      loop do
        break unless @inbox.empty?
      end
      @inbox.pop
    end
  rescue Timeout::Error
    [self, :timeout, nil]
  end

  def heartbeat
    @neighbors.each do |node|
      node.send self, :heartbeat
    end
  end
end
