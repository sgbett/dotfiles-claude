# frozen_string_literal: true

module SkillSupport
  module Testing
    # A copy of a skill's scripts in the sandbox, in a git checkout of their
    # own whose HEAD is origin's default branch, with skills/_support linked
    # beside them. An end-to-end run of the copy finds its own checkout
    # reviewed (ScriptsCheckout), whatever state this repository is in, until
    # the spec changes the copy.
    module SkillClone
      SETUP = [%w[init --quiet --initial-branch=master], %w[add .], %w[commit --quiet -m Scripts],
               %w[update-ref refs/remotes/origin/master HEAD],
               %w[symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master]].freeze

      # The copy of skills/+skill+, its bin/ and lib/, made on first use.
      def skill_clone(skill)
        @skill_clones ||= {}
        @skill_clones[skill] ||= clone_skill(skill, sandbox.path('clone'))
      end

      private

      def clone_skill(skill, root)
        directory = File.join(root, 'skills', skill)
        FileUtils.mkdir_p(directory)
        %w[bin lib].each do |part|
          FileUtils.cp_r(File.join(repository_root, 'skills', skill, part), directory, preserve: true)
        end
        File.symlink(File.join(repository_root, 'skills', '_support'), File.join(root, 'skills', '_support'))
        SETUP.each { |arguments| system('git', '-C', root, *arguments, exception: true) }
        directory
      end
    end
  end
end
