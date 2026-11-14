# frozen_string_literal: true

module SkillSupport
  module Testing
    # Isolates one example: an empty GH_CONFIG_DIR, a dummy GH_TOKEN and no
    # other GitHub credential or routing variable, a git configuration of its
    # own, and a fresh git repository as the working directory. A spec that
    # misses a stub can then reach neither a real issue nor a real .git/do/.
    class Sandbox
      DUMMY_TOKEN = 'dummy'
      CLEARED_VARIABLES = %w[GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN GH_HOST GH_REPO].freeze
      GIT_IDENTITY = {
        'GIT_AUTHOR_NAME' => 'Skill Spec',
        'GIT_AUTHOR_EMAIL' => 'skill-spec@example.invalid',
        'GIT_COMMITTER_NAME' => 'Skill Spec',
        'GIT_COMMITTER_EMAIL' => 'skill-spec@example.invalid'
      }.freeze

      attr_reader :root

      # Yields a prepared sandbox with the working directory inside it, then
      # removes it and restores the environment.
      def self.open
        saved_environment = ENV.to_h
        Dir.mktmpdir('skill-spec-') do |directory|
          sandbox = new(File.realpath(directory))
          sandbox.prepare
          Dir.chdir(sandbox.work_directory) { yield sandbox }
        end
      ensure
        ENV.replace(saved_environment)
      end

      def initialize(root)
        @root = root
      end

      def path(*parts)
        File.join(root, *parts)
      end

      def work_directory
        path('work')
      end

      def gh_config_directory
        path('gh-config')
      end

      def git_config_file
        path('gitconfig')
      end

      def prepare
        FileUtils.mkdir_p([work_directory, gh_config_directory])
        File.write(git_config_file, '')
        isolate_environment
        initialise_git_repository
      end

      private

      def isolate_environment
        CLEARED_VARIABLES.each { |name| ENV.delete(name) }
        ENV.update(GIT_IDENTITY)
        ENV.update(
          'GH_CONFIG_DIR' => gh_config_directory,
          'GH_TOKEN' => DUMMY_TOKEN,
          'GIT_CONFIG_GLOBAL' => git_config_file,
          'GIT_CONFIG_NOSYSTEM' => '1'
        )
      end

      def initialise_git_repository
        output, status = Open3.capture2e('git', 'init', '--quiet', '--initial-branch=master', work_directory)
        raise "git init failed: #{output}" unless status.success?
      end
    end
  end
end
