# frozen_string_literal: true

require 'securerandom'

class Node
  def initialize(name)
    @name = name
    @uuid = SecureRandom.uuid
    @neighbors = []
    init_log
    init_actor
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
      node.send @name, 'hello'
    end
  end

  def send(sender, message)
    @actor << [sender, message]
  end

  def take
    @actor.take
  end

  private

  def init_log
    @log = [{ index: 0, state: nil }]
  end

  def init_actor
    @actor = Ractor.new name: @name do
      loop do
        sender, message = Ractor.receive
        puts "#{sender} sent #{message} to #{name}"
      end
    end
  end
end
