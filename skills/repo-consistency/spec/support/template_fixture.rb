# frozen_string_literal: true

module RepoConsistency
  module Testing
    # A template directory in the sandbox, shaped as profiles/git-workflow
    # is, with a short profile beside it, so that a spec controls every
    # byte a vendored copy is compared against. The real template has specs
    # of its own (drift_spec.rb and the end-to-end run in audit_spec.rb).
    module TemplateFixture
      PULL_REQUEST_PARAMETERS = {
        'required_approving_review_count' => 0, 'require_extra_approval_for_unattributed_changes' => false,
        'dismiss_stale_reviews_on_push' => false,
        'require_code_owner_review' => false, 'require_last_push_approval' => false,
        'required_review_thread_resolution' => false, 'allowed_merge_methods' => ['merge']
      }.freeze
      RULESET = {
        'name' => 'Git workflow', 'target' => 'branch', 'enforcement' => 'active', 'bypass_actors' => [],
        'conditions' => { 'ref_name' => { 'include' => ['~DEFAULT_BRANCH'], 'exclude' => [] } },
        'rules' => [{ 'type' => 'deletion' }, { 'type' => 'non_fast_forward' },
                    { 'type' => 'pull_request', 'parameters' => PULL_REQUEST_PARAMETERS }]
      }.freeze
      REPOSITORY = { 'allow_squash_merge' => false, 'allow_rebase_merge' => false, 'allow_merge_commit' => true,
                     'allow_update_branch' => false }.freeze
      HOOK_COMMAND = 'sh "$CLAUDE_PROJECT_DIR/.claude/hooks/push-guard"'
      HOOKS_SETTINGS = {
        'hooks' => { 'PreToolUse' => [{ 'matcher' => 'Bash',
                                        'hooks' => [{ 'type' => 'command', 'command' => HOOK_COMMAND,
                                                      'timeout' => 5 }] }] }
      }.freeze
      HOOKS = {
        'push-guard' => "#!/bin/sh\n# vendored from sgbett/dotfiles-claude profiles/git-workflow/hooks/push-guard\n" \
                        "exit 0\n",
        'push-guard.rb' => "# vendored from sgbett/dotfiles-claude profiles/git-workflow/hooks/push-guard.rb\nexit 0\n"
      }.freeze
      PROFILE = "<!-- profiles/git-workflow.md -->\n\n# Git workflow\n\n- Default branch: `master`\n" \
                "- All changes land via PR.\n"
      # The two header lines a vendored copy of the profile carries.
      HEADER = "<!-- vendored from sgbett/dotfiles-claude profiles/git-workflow.md -->\n\n"

      # The sandbox's template directory, written on first use.
      def template_directory
        @template_directory ||= write_template(sandbox.path('profiles', 'git-workflow'))
      end

      def write_template(directory)
        FileUtils.mkdir_p(File.join(directory, 'hooks'))
        { 'ruleset.json' => RULESET, 'repository.json' => REPOSITORY, 'hooks.json' => HOOKS_SETTINGS }
          .each { |name, body| File.write(File.join(directory, name), "#{JSON.pretty_generate(body)}\n") }
        HOOKS.each { |name, text| File.write(File.join(directory, 'hooks', name), text) }
        File.write(File.join(directory, '..', 'git-workflow.md'), PROFILE)
        directory
      end
    end
  end
end
