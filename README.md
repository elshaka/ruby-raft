# ruby-raft

A simple Ruby implementation of the Raft algorithm for a ditributed system where multiple nodes communicate with each other to achieve consensus on a shared state by sending messages to each other.

Each node holds a log of all state transitions and received messages.

## Implementation limitations with MRI

The implementation is threaded. Due to the MRI's Global Interpreter Lock (GIL), which prevents true parallelism, Raft heartbeat timeouts need to be set to higher than usual values to avoid frequent leader election splits. This can significantly slow down the behavior of the nodes.

As a temporary solution, you can use JRuby, which allows true parallel threads. In this case, the code will set the heartbeat timeouts to shorter values.

## Install

```
bundle install
```

## Basic usage

Create some nodes:
```ruby
require './lib/node'

node1 = Node.new "node1"
node2 = Node.new "node2"
node3 = Node.new "node3"
```

Connect them to each other
```ruby
node1.add_neighbor node2
node1.add_neighbor node3
node2.add_neighbor node1
node2.add_neighbor node3
node3.add_neighbor node1
node3.add_neighbor node2
```

Start the nodes

```ruby
[node1, node2, node3].each(&start)
```

Following the Raft algorithm, all nodes are intially followers but after a timeout one of them will become the leader through an election. After a leader is elected the group of nodes is ready to receive state proposals.

The following code would send 3 state proposals, each to a node picked randomly.

```ruby
[1, 2, 3].each do |state|
  [node1, node2, node3].sample.propose_state state
end
```

In case a follower node receives a state proposal it will foward it to the leader.

To stop the nodes you'd do

```ruby
[node1, node2, node3].each(&stop)
[node1, node2, node3].each(&join) # Let all node threads finish
```

For reference you can look at the spec or run the rake `debug` task

```
bundle exec rake debug
```

The task does the following:

- Starts a cluster of nodes
- Proposes states
- Stops the cluster of nodes
- Shows the log (state and messages) for each node
- Opens a runtime console

## Testing

```
bundle exec rspec
```
