# frozen_string_literal: true

require 'spec_helper'
require './lib/node'

describe Node do
  it 'initializes with a unique id' do
    nodes_ids = 10.times.map { Node.new.id }
    expect(nodes_ids.uniq).to eq(nodes_ids)
  end
end
