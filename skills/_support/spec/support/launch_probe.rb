# frozen_string_literal: true

module SkillSupport
  module Testing
    # A throwaway skill, "probe", built in the sandbox from the launcher
    # templates and laid out as an install can be: the skill reached through a
    # symlink to its directory, with skills/_support beside its real location
    # and not beside the link. Its entry reports the Ruby and environment it
    # runs with, as a proceed outcome.
    class LaunchProbe
      SUPPORT = File.join(Helpers::REPOSITORY_ROOT, 'skills', '_support')
      TEMPLATES = File.join(SUPPORT, 'templates')
      PROBED_VARIABLES = %w[RUBYOPT RUBYLIB GEM_HOME GEM_PATH BUNDLE_GEMFILE].freeze
      # Follows the entry template, so Ruby 2 must be able to parse it too.
      REPORT = <<~RUBY.freeze
        exit SkillSupport::Cli.run('probe', reasons: []) {
          SkillSupport::Outcome.proceed(
            ruby_version: RUBY_VERSION,
            ruby: RbConfig.ruby,
            bundler_loaded: $LOADED_FEATURES.any? { |feature| feature.include?('bundler') },
            environment: ENV.to_h.select { |name, _| #{PROBED_VARIABLES.inspect}.include?(name) },
            arguments: ARGV
          )
        }
      RUBY

      # +command+ is bin/probe reached through the symlinked skill directory;
      # +entry+ is lib/probe.rb at its real location.
      attr_reader :command, :entry

      def initialize(sandbox, with_support: true)
        @skills = sandbox.path('clone', 'skills')
        @link = sandbox.path('install', 'skills', 'probe')
        @command = File.join(@link, 'bin', 'probe')
        @entry = File.join(@skills, 'probe', 'lib', 'probe.rb')
        build(with_support)
      end

      private

      def build(with_support)
        skill = File.join(@skills, 'probe')
        FileUtils.mkdir_p([File.join(skill, 'bin'), File.join(skill, 'lib'), File.dirname(@link)])
        FileUtils.cp(File.join(TEMPLATES, 'bin_stub'), File.join(skill, 'bin', 'probe'), preserve: true)
        File.write(@entry, File.read(File.join(TEMPLATES, 'entry_preamble.rb')) + REPORT)
        File.symlink(SUPPORT, File.join(@skills, '_support')) if with_support
        File.symlink(skill, @link)
      end
    end
  end
end
