# frozen_string_literal: true

require 'timeout'

class Raft
  TIMING_FACTOR = RUBY_ENGINE == 'jruby' ? 1 : 5

  HEARTBEAT_INTERVAL = TIMING_FACTOR * 0.1
  HEARTBEAT_TIMEOUT = HEARTBEAT_INTERVAL * 2
  HEARTBEAT_TIMEOUT_RAND_MULTIPLIER = TIMING_FACTOR
  MAX_HEARTBEAT_TIMEOUT = HEARTBEAT_TIMEOUT + HEARTBEAT_TIMEOUT_RAND_MULTIPLIER

  attr_reader :status, :leader

  def initialize(node)
    @node = node
    @role = :follower
    @term = 1
    @last_voted_term = 1
    @leader = nil
    @proposed_state = nil
  end

  def start
    @neighbors_count = @node.neighbors.count

    @inbox_thread = Thread.new do
      loop do
        @message = receive
        if !%i[timeout heartbeat stop].include?(@message[:type]) ||
           (@message[:type] == :heartbeat && @message[:content][:proposed_state])
          @node.inbox_log << @message
        end

        case @message[:type]
        when :timeout
          handle_timeout unless leader?
        when :leader_election_request
          handle_leader_election_request
        when :leader_election_response
          handle_leader_election_response
        when :propose_state
          handle_propose_state
        when :heartbeat
          handle_heartbeat
        when :state_appended
          handle_state_appended
        when :commit_state
          handle_commit_state
        when :stop
          break
        end
      end
    end

    @heartbeat_thread = Thread.new do
      loop do
        break unless @node.running?

        if leader?
          @node.send_to_all_neighbors :heartbeat, { term: @term, proposed_state: @proposed_state }
        end
        sleep HEARTBEAT_INTERVAL
      end
    end
  end

  def handle_timeout
    puts "#{@node.name}: leader heartbeat timeout (#{@message[:content]} seconds)" if follower?
    puts "#{@node.name}: leader election timeout (#{@message[:content]} seconds)" if candidate?
    request_leader_election
  end

  def request_leader_election
    puts "#{@node.name} proposes itself as a leader candidate"
    @leader = nil
    @term += 1
    @role = :candidate
    @votes = []
    @node.send_to_all_neighbors :leader_election_request, @term
  end

  def handle_leader_election_request
    candidate = @message[:sender]
    candidate_term = @message[:content]

    candidate.send @node, :leader_election_response, vote(candidate, candidate_term)
  end

  def vote(candidate, candidate_term)
    if candidate_term <= @last_voted_term
      puts "#{@node.name} rejects #{candidate.name}'s election request (already voted for term #{candidate_term})"
      return false
    end

    @last_voted_term = candidate_term
    candidate_term > @term
  end

  def handle_leader_election_response
    @votes << @message[:content]
    approvals = @votes.count(&:itself)

    if approvals + 1 > required_count
      unless leader?
        @role = :leader
        puts "#{@node.name} is now the leader"
      end
    end
  end

  def required_count
    (@neighbors_count + 1).to_f / 2
  end

  def handle_propose_state
    state = @message[:content]
    if leader?
      puts "#{@node.name} (leader) received a state proposal (#{state})"
      @appending_confirmations = 0
      @proposed_state = { term: @term, state: state }
    else
      puts "#{@node.name} received a state proposal (#{state}) but it's not the leader, fowarding proposal"
      propose_state_to_leader state
    end
  end

  def propose_state_to_leader(state)
    unless @leader
      warn "#{@node.name} (follower) does not have a leader to foward a state proposal, the state proposal has been lost"
      return
    end

    @leader.send @node, :propose_state, state
  end

  def handle_heartbeat
    heartbeat_term = @message[:content][:term]
    heartbeat_log_size = @message[:content][:log_size]

    if heartbeat_term > @term
      @role = :follower
      @leader = @message[:sender]
      @term = heartbeat_term

    elsif heartbeat_term == @term
      @proposed_state = @message[:content][:proposed_state]
      @leader.send @node, :state_appended if @proposed_state
    end
  end

  def handle_state_appended
    return unless @proposed_state
    @appending_confirmations += 1

    if @appending_confirmations + 1 > required_count
      puts "#{@node.name} commits state to the log with #{@appending_confirmations + 1} confirmations (nedded #{required_count})"
      @node.send_to_all_neighbors :commit_state
      commit_state
    end
  end

  def handle_commit_state
    commit_state
  end

  def commit_state
    @node.log << @proposed_state
    @proposed_state = nil
  end

  def join
    @inbox_thread.join
    @heartbeat_thread.join
  end

  def receive
    timeout = (HEARTBEAT_TIMEOUT + HEARTBEAT_TIMEOUT_RAND_MULTIPLIER * rand).round(3)
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

  def max_init_time
    MAX_HEARTBEAT_TIMEOUT
  end

  def leader?
    @role == :leader
  end

  def follower?
    @role == :follower
  end

  def candidate?
    @role == :candidate
  end
end
