# frozen_string_literal: true

require 'securerandom'
require 'timeout'

class Node
  HEARTBEAT_INTERVAL = 0.5
  HEARTBEAT_TIMEOUT = HEARTBEAT_INTERVAL + 1

  attr_reader :uuid, :name

  def initialize(name)
    @name = name
    @uuid = SecureRandom.uuid
    @role = :follower
    @status = :alive
    @neighbors = []
    @inbox = Queue.new
  end

  def add_neighbor(node)
    @neighbors << node unless @neighbors.include?(node)
  end

  def propose_state(state); end

  def send(sender, type, content = nil)
    @inbox << [sender, type, content]
  end

  def join
    @messages_thread.join
    @heartbeat_thread.join
  end

  def become_leader
    @role = :leader
    puts "#{name} is now a leader"
  end

  def become_follower
    @role = :follower
    puts "#{name} is now a follower"
  end

  def kill
    @status = :dead
  end

  def start
    @messages_thread = Thread.new do
      loop do
        break if dead?

        sender, type, content = receive

        case type
        when :heartbeat
          puts "#{name} received heartbeat from leader #{sender.name}"
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
