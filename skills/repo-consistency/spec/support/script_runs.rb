# frozen_string_literal: true

module RepoConsistency
  module Testing
    # Running git-settings end to end, against the gh shim (install_gh_shim),
    # which serves fixtures by exact arguments.
    module ScriptRuns
      # Runs bin/git-settings with +arguments+, returning the exit code, the
      # output parsed as JSON (nil for none) and stderr.
      def run_script(*arguments, environment: {})
        script = File.join(repository_root, 'skills', 'repo-consistency', 'bin', 'git-settings')
        stdout, stderr, status = Open3.capture3(environment, script, *arguments)
        [status.exitstatus, stdout.empty? ? nil : JSON.parse(stdout), stderr]
      end

      # What a calling directory can hand any Ruby started there: Bundler,
      # loaded against a Gemfile that names a gem which doesn't exist.
      def hostile_environment
        File.write('Gemfile', "source 'https://rubygems.org'\ngem 'skill-support-no-such-gem'\n")
        { 'RUBYOPT' => '-rbundler/setup', 'BUNDLE_GEMFILE' => File.expand_path('Gemfile') }
      end
    end
  end
end
