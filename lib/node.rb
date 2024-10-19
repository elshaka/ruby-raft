# frozen_string_literal: true

require 'securerandom'
require 'timeout'

class Node
  attr_reader :uuid, :name

  def initialize(name)
    @name = name
    @uuid = SecureRandom.uuid
    @neighbors = []
    @inbox = Queue.new
    init_log
    init_thread
  end

  def add_neighbor(node)
    @neighbors << node unless @neighbors.include?(node)
  end

  def propose_state(state); end

  def simulate_partition(partition); end

  def retrieve_log
    @log
  end

  def hello
    @neighbors.each do |node|
      node.send self, :hello
    end
  end

  def send(sender, type, content = nil)
    @inbox << [sender, type, content]
  end

  def join
    @thread.join
  end

  private

  def receive
    Timeout.timeout(1) do
      loop do
        break unless @inbox.empty?
      end
      @inbox.pop
    end
  rescue Timeout::Error => e
    [self, :timeout, nil]
  end

  def init_log
    @log = [{ index: 0, state: nil }]
  end

  def init_thread
    @thread = Thread.new do
      loop do
        sender, type, content = receive

        case type
        when :hello
          puts "#{sender.name} said hello to #{self.name}"
        when :timeout
          puts "#{self.name} received no message (timeout)"
        end
      end
    end
  end
end
