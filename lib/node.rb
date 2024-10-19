# frozen_string_literal: true

require 'securerandom'
require 'timeout'

class Node
  HEARTBEAT_INTERVAL = 0.5
  HEARTBEAT_TIMEOUT = HEARTBEAT_INTERVAL + 1

  attr_reader :uuid, :name, :log
  attr_accessor :leader

  def initialize(name)
    @name = name
    @uuid = SecureRandom.uuid
    @role = :follower
    @status = :alive
    @neighbors = []
    @leader = nil
    @inbox = Queue.new
    @log = []
  end

  def add_neighbor(node)
    @neighbors << node unless @neighbors.include?(node)
  end

  def start
    @receive_thread = Thread.new do
      loop do
        break if dead?

        sender, type, content = receive

        case type
        when :heartbeat
          puts "#{name} received heartbeat from leader #{sender.name}"
        when :propose_state
          if leader?
            puts "#{name} (leader) received a state proposal (#{content})"
            @log << content
            propagate_state content
          else
            puts "#{name} received a state proposal but it's not the leader, fowarding proposal"
            propose_state_to_leader content
          end
        when :set_state
          unless leader?
            @log << content
          end
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

    @send_thread = Thread.new do
      loop do
        break if dead?

        heartbeat if leader?
        sleep HEARTBEAT_INTERVAL
      end
    end
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
      node.send self, :set_state, state
    end
    puts "State #{state} has been propagated"
  end

  def join
    @receive_thread.join
    @send_thread.join
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
