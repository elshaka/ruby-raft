# frozen_string_literal: true

require 'securerandom'

class Node
  attr_reader :id

  def initialize
    @id = SecureRandom.uuid
  end
end
