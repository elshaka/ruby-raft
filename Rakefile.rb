# frozen_string_literal: true

require 'rake'
require 'rubocop/rake_task'

task :console do
  require_relative 'lib/node'

  binding.irb
end
