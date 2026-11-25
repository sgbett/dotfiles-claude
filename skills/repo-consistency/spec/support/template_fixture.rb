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
      PROTECTED_BRANCHES = {
        'name' => 'Project and release branches', 'target' => 'branch', 'enforcement' => 'active',
        'bypass_actors' => [],
        'conditions' => { 'ref_name' => { 'include' => ['refs/heads/project/*/master', 'refs/heads/releases/*'],
                                          'exclude' => [] } },
        'rules' => [{ 'type' => 'deletion' }, { 'type' => 'non_fast_forward' }]
      }.freeze
      TAGS = {
        'name' => 'Tags', 'target' => 'tag', 'enforcement' => 'active', 'bypass_actors' => [],
        'conditions' => { 'ref_name' => { 'include' => ['~ALL'], 'exclude' => [] } },
        'rules' => [{ 'type' => 'deletion' }, { 'type' => 'update' }]
      }.freeze
      # By file, the default branch's first, as Template reads them.
      RULESETS = { 'ruleset.json' => RULESET, 'ruleset-project-release.json' => PROTECTED_BRANCHES,
                   'ruleset-tags.json' => TAGS }.freeze
      REPOSITORY = { 'allow_squash_merge' => false, 'allow_rebase_merge' => false, 'allow_merge_commit' => true,
                     'allow_update_branch' => false }.freeze
      PROFILE = "<!-- profiles/git-workflow.md -->\n\n# Git workflow\n\n- Default branch: `master`\n" \
                "- All changes land via PR.\n"
      # The two header lines a vendored copy of the profile carries.
      HEADER = "<!-- vendored from sgbett/dotfiles-claude profiles/git-workflow.md -->\n\n"

      # The sandbox's template directory, written on first use.
      def template_directory
        @template_directory ||= write_template(sandbox.path('profiles', 'git-workflow'))
      end

      def write_template(directory)
        FileUtils.mkdir_p(directory)
        RULESETS.merge('repository.json' => REPOSITORY)
                .each { |name, body| File.write(File.join(directory, name), "#{JSON.pretty_generate(body)}\n") }
        File.write(File.join(directory, '..', 'git-workflow.md'), PROFILE)
        directory
      end
    end
  end
end
