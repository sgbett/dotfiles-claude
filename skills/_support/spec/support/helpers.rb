# frozen_string_literal: true

module SkillSupport
  module Testing
    # What every skill's specs can call.
    module Helpers
      REPOSITORY_ROOT = File.expand_path('../../../..', __dir__)

      # The example's Sandbox; the working directory is its git repository.
      attr_reader :sandbox

      def repository_root
        REPOSITORY_ROOT
      end

      # A FakeRunner to inject wherever the code takes a runner:. Every call
      # expected of it must have been made by the end of the example.
      def fake_runner
        @fake_runner ||= FakeRunner.new
      end

      # Expects Gh#logged_in?'s call for +host+ on the fake runner, answered
      # as gh answers with an account there or, unless +logged_in+, without.
      def expect_gh_login(host = 'github.com', logged_in: true)
        fake_runner.expect_call(['gh', 'auth', 'status', '--active', '--hostname', host],
                                exit_status: logged_in ? 0 : 1,
                                stderr: logged_in ? '' : "You are not logged into any accounts on #{host}\n")
      end

      # The path of +name+ under spec/fixtures/ of the skill whose spec is
      # running.
      def fixture_path(name)
        spec_file = Pathname(RSpec.current_example.metadata[:absolute_file_path])
        spec_directory = spec_file.ascend.find { |path| path.basename.to_s == 'spec' }
        path = spec_directory.join('fixtures', name)
        raise ArgumentError, "no fixture at #{path}" unless path.file?

        path.to_s
      end

      def fixture(name)
        File.read(fixture_path(name))
      end

      # Puts the gh shim first on PATH for an end-to-end spec; see GhShim.
      def install_gh_shim(entries)
        GhShim.install(sandbox, entries)
      end
    end
  end
end
