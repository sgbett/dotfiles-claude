# frozen_string_literal: true

module Do
  module Testing
    # A copy of the do skill's scripts in the sandbox, in a git checkout of
    # their own whose HEAD is origin's default branch, with skills/_support
    # linked beside them. An end-to-end run of the copy finds its own
    # checkout reviewed, whatever state this repository is in.
    module ScriptsClone
      SETUP = [%w[init --quiet --initial-branch=master], %w[add .], %w[commit --quiet -m Scripts],
               %w[update-ref refs/remotes/origin/master HEAD],
               %w[symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master]].freeze

      # The copy's bin/preflight.
      def scripts_clone
        root = sandbox.path('clone')
        skill = File.join(root, 'skills', 'do')
        FileUtils.mkdir_p(skill)
        %w[bin lib].each do |part|
          FileUtils.cp_r(File.join(repository_root, 'skills', 'do', part), skill, preserve: true)
        end
        File.symlink(File.join(repository_root, 'skills', '_support'), File.join(root, 'skills', '_support'))
        SETUP.each { |arguments| system('git', '-C', root, *arguments, exception: true) }
        File.join(skill, 'bin', 'preflight')
      end
    end
  end
end
