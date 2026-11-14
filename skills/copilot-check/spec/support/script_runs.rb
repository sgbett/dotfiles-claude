# frozen_string_literal: true

module CopilotCheck
  module Testing
    # Running setup, threads and rereview end to end, against the gh shim
    # (install_gh_shim), which serves fixtures by exact arguments and stdin.
    module ScriptRuns
      # Runs +script+ ("setup", "threads" or "rereview") from bin/ with
      # +arguments+, returning the exit code, the output parsed as JSON (nil
      # for none), and stderr.
      def run_script(script, *arguments, environment: {})
        path = File.join(repository_root, 'skills', 'copilot-check', 'bin', script)
        stdout, stderr, status = Open3.capture3(environment, path, *arguments)
        [status.exitstatus, stdout.empty? ? nil : JSON.parse(stdout), stderr]
      end

      # The request a recorded GraphQL fixture was made with, as the code
      # sends it, which the gh shim matches byte for byte.
      def recorded_request(name)
        JSON.generate(JSON.parse(fixture("graphql/#{name}.request.json")))
      end

      # The gh shim's entry for the checkout's repository, as recorded.
      def repo_view_entry
        { args: GateCalls::REPO_VIEW.drop(1), stdout_file: fixture_path('repo-view/checkout.json') }
      end

      # The gh shim's entry for a GraphQL call sending +request+, answered
      # as +answer+ says.
      def graphql_entry(request, **answer)
        { args: GateCalls::GRAPHQL.drop(1), stdin: request, **answer }
      end

      # The gh shim's entry for the GraphQL call recorded as +name+.
      def recorded_graphql_entry(name)
        graphql_entry(recorded_request(name), stdout_file: fixture_path("graphql/#{name}.json"))
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
