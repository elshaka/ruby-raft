# frozen_string_literal: true

require 'timeout'

class Raft
  HEARTBEAT_INTERVAL = 1
  HEARTBEAT_TIMEOUT = HEARTBEAT_INTERVAL + 1
  HEARTBEAT_TIMEOUT_RAND_MULTIPLIER = 5
  MAX_HEARTBEAT_TIMEOUT = HEARTBEAT_TIMEOUT + HEARTBEAT_TIMEOUT_RAND_MULTIPLIER

  def initialize(node)
    @node = node
    @status = :following
    @leader = nil
  end

  def start
    @inbox_thread = Thread.new do
      loop do
        @message = receive
        @node.inbox_log << @message unless %i[timeout heartbeat stop].include? @message[:type]

        case @message[:type]
        when :heartbeat
          handle_heartbeat
        when :propose_state
          handle_propose_state
        when :log_state
          handle_log_state
        when :timeout
          handle_timeout
        when :leader_election_request
          handle_leader_election_request
        when :leader_election_vote
          handle_leader_election_vote
        when :set_leader
          handle_set_leader
        when :no_leader
          handle_no_leader
        when :stop
          break
        end
      end
    end

    @heartbeat_thread = Thread.new do
      loop do
        break unless @node.running?

        @node.send_to_all_neighbors :heartbeat if leading?
        sleep HEARTBEAT_INTERVAL
      end
    end
  end

  def handle_heartbeat; end

  def handle_propose_state
    state = @message[:content]
    if leading?
      puts "#{@node.name} (leader) received a state proposal (#{state})"
      log_state state
      propagate_state state
    else
      puts "#{@node.name} received a state proposal (#{state}) but it's not the leader, fowarding proposal"
      propose_state_to_leader state
    end
  end

  def handle_log_state
    log_state @message[:content]
  end

  def handle_timeout
    return if leading?
    return if voting?

    puts "#{@node.name} received no leader heartbeat after #{@message[:content]} seconds, requesting a leader election"
    @leader = nil
    @status = :voting
    request_leader_election
  end

  def handle_leader_election_request
    @status = :voting

    election_initiator = @message[:sender]
    # TODO: Improve voting criteria
    election_initiator.send @node, :leader_election_vote, election_initiator
  end

  def handle_leader_election_vote
    @votes << { voter: @message[:sender], candidate: @message[:content] }
    return unless @votes.count == @node.neighbors.count

    approvals = @votes.select { |vote| vote[:candidate] == @node }
    if approvals.count >= (@node.neighbors.count) / 2
      @node.send_to_all_neighbors :set_leader
      @status = :leading
      puts "#{@node.name} is now the leader"
    else
      @node.send_to_all_neighbors :no_leader
      @status = :following
    end
  end

  def handle_set_leader
    @leader = @message[:sender]
    @status = :following
  end

  def handle_no_leader
    @leader = nil
    @status = :following
  end

  def propose_state_to_leader(state)
    unless @leader
      warn "Follower node #{@node.name} does not have a leader to foward a state proposal, the state proposal has been lost"
      return
    end

    @leader.send @node, :propose_state, state
  end

  def propagate_state(state)
    raise "Node #{@node} it's not the leader and cannot propagate the state #{state}" unless leading?

    @node.send_to_all_neighbors :log_state, state
  end

  def log_state(content)
    @node.log << content
  end

  def request_leader_election
    raise "Node #{@node} is the leader and cannot request a leader election" if leading?

    @status = :electing
    @votes = []
    @node.send_to_all_neighbors :leader_election_request
  end

  def become_leader

  end

  def join
    @inbox_thread.join
    @heartbeat_thread.join
  end

  def receive
    timeout = HEARTBEAT_TIMEOUT + HEARTBEAT_TIMEOUT_RAND_MULTIPLIER * rand
    Timeout.timeout(timeout) do
      loop do
        break unless @node.inbox.empty? && @node.running?
      end
      return { sender: @node, type: :stop, content: nil } unless @node.running?

      @node.inbox.pop
    end
  rescue Timeout::Error
    { sender: @node, type: :timeout, content: timeout }
  end

  def leading?
    @status == :leading
  end

  def following?
    @status == :following
  end

  def voting?
    @status == :voting
  end
end
