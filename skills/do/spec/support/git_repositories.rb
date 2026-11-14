# frozen_string_literal: true

module Do
  module Testing
    # Builds real git repositories inside the example's sandbox, for the
    # specs of pre-flight's git layer.
    module GitRepositories
      # Runs git, failing the example if git fails, and returns its output.
      def git(*arguments, chdir: Dir.pwd)
        output, status = Open3.capture2e('git', *arguments, chdir: chdir)
        raise "git #{arguments.join(' ')} failed: #{output}" unless status.success?

        output
      end

      # Commits nothing but +message+ and returns the new commit's name.
      def commit(message, chdir: Dir.pwd)
        git('commit', '--quiet', '--allow-empty', '-m', message, chdir: chdir)
        git('rev-parse', 'HEAD', chdir: chdir).chomp
      end

      # The line git log prints for +commit+ in the form pre-flight lists.
      def log_line(commit, chdir: Dir.pwd)
        git('log', '-1', '--format=%h %an %s', commit, chdir: chdir).chomp
      end

      # A bare repository in the sandbox, added to the working directory's
      # repository as origin, with a first commit on master pushed to it.
      def bare_origin
        remote = sandbox.path('remote.git')
        git('init', '--quiet', '--bare', '--initial-branch=master', remote)
        git('remote', 'add', 'origin', remote)
        commit('First')
        git('push', '--quiet', 'origin', 'master')
        remote
      end
    end
  end
end
