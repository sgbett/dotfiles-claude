# frozen_string_literal: true

# This preamble is skills/_support/templates/entry_preamble.rb, copied unchanged.
# Keep the whole file to syntax Ruby 2 can parse: Ruby parses a file before
# running any of it, so newer syntax anywhere here would fail before the
# version check could explain. The skill's own code goes in files required
# after the preamble.
if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('3.1')
  warn "#{File.basename(__FILE__, '.rb')}: tool failure: Ruby #{RUBY_VERSION} is too old, 3.1 or later is " \
       'needed; run mise install in the repository that holds this skill'
  exit 1
end

support = File.expand_path('../../_support/lib/skill_support.rb', __dir__)
unless File.file?(support)
  warn "#{File.basename(__FILE__, '.rb')}: tool failure: #{support} is missing; install skills/ as one unit"
  exit 1
end
require support

require_relative 'do/record'

exit SkillSupport::Cli.run('record', reasons: Do::Reasons::RECORD) { Do::Record.call(ARGV) }
