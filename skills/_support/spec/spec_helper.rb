# frozen_string_literal: true

# Loaded for every skill's specs by the repository's .rspec, so `rspec` from
# the repository root runs them all.
require 'fileutils'
require 'json'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'stringio'
require 'tmpdir'
require_relative '../lib/skill_support'
Dir[File.join(__dir__, 'support', '*.rb')].each { |file| require file }

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }
  config.order = :random
  Kernel.srand(config.seed)
  config.include SkillSupport::Testing::Helpers

  config.around do |example|
    SkillSupport::Testing::Sandbox.open do |sandbox|
      @sandbox = sandbox
      example.run
    end
  end

  config.after { @fake_runner&.verify! }
end
