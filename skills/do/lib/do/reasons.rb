# frozen_string_literal: true

module Do
  # Every reason preflight can stop or ask for, each with its message. A
  # message is a constant, so no GitHub text can reach one; whatever an
  # answer needs travels beside it in validated fields.
  module Reasons
    NOT_AN_ISSUE = :not_an_issue
    NO_ORIGIN = :no_origin
    COMMENTS_TRUNCATED = :comments_truncated
    UNTRUSTED_AUTHOR_CRITERIA = :untrusted_author_criteria
    GATE_ADVISORY = :gate_advisory
    GATE_RECORD_MISSING = :gate_record_missing
    REMOTE_MISSING = :remote_missing
    HOST_MISMATCH = :host_mismatch
    REMOTE_UNRESOLVABLE = :remote_unresolvable
    PUSH_REMOTE_NOT_THIS_REPOSITORY = :push_remote_not_this_repository
    PR_TARGET_NOT_THIS_REPOSITORY = :pr_target_not_this_repository
    BASE_MISSING = :base_missing
    CHECKED_OUT_PR = :checked_out_pr
    UNTRUSTED_PULL_REQUEST = :untrusted_pull_request
    LOCAL_BRANCH_UNPUSHED = :local_branch_unpushed
    SCRIPTS_UNREVIEWED = :scripts_unreviewed

    STOPS = [NOT_AN_ISSUE, GATE_ADVISORY, REMOTE_MISSING, HOST_MISMATCH, REMOTE_UNRESOLVABLE,
             PUSH_REMOTE_NOT_THIS_REPOSITORY, PR_TARGET_NOT_THIS_REPOSITORY, BASE_MISSING, CHECKED_OUT_PR,
             UNTRUSTED_PULL_REQUEST].freeze
    ASKS = [NO_ORIGIN, COMMENTS_TRUNCATED, UNTRUSTED_AUTHOR_CRITERIA, GATE_RECORD_MISSING, LOCAL_BRANCH_UNPUSHED,
            SCRIPTS_UNREVIEWED].freeze
    ALL = (STOPS + ASKS).freeze

    # Why a reference names no issue, keyed by what it turned out to be.
    NOT_AN_ISSUE_MESSAGES = {
      not_a_reference: 'That is not an issue reference. Give an issue number, owner/repo#N, or ' \
                       'https://<host>/<owner>/<repo>/issues/<N>.',
      pull_request: 'That number is a pull request, not an issue.',
      missing_issue: 'That repository has no issue with that number that you can see.',
      missing_repository: 'No repository by that name is visible to you.',
      moved: 'The issue has moved to another repository. Run /do with its new reference.'
    }.freeze

    RUN_FROM_A_CHECKOUT = "Run /do owner/repo#N from a checkout of the issue's repository or of a fork of it."

    MESSAGES = {
      GATE_ADVISORY => 'An open security gate finding was answered advisory: the owner handles it through a ' \
                       'private security advisory, so this run stops. Push nothing.',
      NO_ORIGIN => 'A bare number names an issue in the repository origin resolves to, and this directory has ' \
                   'no origin remote with a URL. Ask the user for the issue as owner/repo#N.',
      COMMENTS_TRUNCATED => 'The issue has more than 100 comments and none of the first 100 is a trusted ' \
                            'breakdown, so the ledger may be on a later page. Ask the user whether one exists.',
      UNTRUSTED_AUTHOR_CRITERIA => "The issue's or its parent's author isn't trusted, and the ledger records no " \
                                   'adopted acceptance criteria. Ask the user which criteria to adopt; once ' \
                                   'confirmed, record them in the ledger under "### Adopted acceptance criteria".',
      GATE_RECORD_MISSING => 'The ledger has an open gate line that the local gate file lacks. Ask the user ' \
                             'before building, pushing or any rewind.',
      REMOTE_MISSING => "The push remote isn't a remote of this checkout, or has no push URL. #{RUN_FROM_A_CHECKOUT}",
      HOST_MISMATCH => "A URL the push remote pushes to isn't on the issue's host. #{RUN_FROM_A_CHECKOUT}",
      REMOTE_UNRESOLVABLE => "A URL the push remote pushes to doesn't resolve to a repository through GitHub " \
                             "(gh's answer is in session_only.stderr), and /do never reads the repository from " \
                             "the URL itself. #{RUN_FROM_A_CHECKOUT}",
      PUSH_REMOTE_NOT_THIS_REPOSITORY => "The push remote pushes to a repository that is neither the issue's nor " \
                                         "a fork of it. #{RUN_FROM_A_CHECKOUT}",
      PR_TARGET_NOT_THIS_REPOSITORY => 'The conventions send the pull request to a repository other than the ' \
                                       "issue's, and /do opens it only against the issue's repository. " \
                                       "#{RUN_FROM_A_CHECKOUT}",
      BASE_MISSING => "The base branch the conventions call for doesn't exist on the issue's repository. Tell " \
                      'the user: /do never creates or pushes a base branch.',
      CHECKED_OUT_PR => 'The local branch is a checked-out pull request: its remote or pushRemote is a URL or ' \
                        'another remote, or it merges a refs/pull/ ref. /do never resumes on it, nor checks it ' \
                        'out, builds or tests it. When branch.resume_from_push_remote is true, the push remote ' \
                        'has the branch: the user can rename or delete the local branch, then run /do again to ' \
                        "resume from the push remote's copy in a fresh worktree.",
      UNTRUSTED_PULL_REQUEST => "A pull request by an author the Trust rule doesn't trust is open on the branch " \
                                '(branch.pull_requests). /do never adopts it: tell the user, who can choose ' \
                                'another branch or deal with that pull request first.',
      LOCAL_BRANCH_UNPUSHED => 'The local branch was never pushed, or has commits the push remote lacks ' \
                               '(session_only.local_branch_commits). Show them to the user and ask whether to ' \
                               'resume on this branch; on a yes, run check again with accept_with added.',
      SCRIPTS_UNREVIEWED => 'The checkout these scripts run from has changes under skills/do or ' \
                            "skills/_support, or its HEAD isn't in its default branch, so they may not be the " \
                            'reviewed scripts (session_only.scripts_changes). Ask the user whether to go on with ' \
                            'them; on a yes, run check again with accept_with added.'
    }.transform_values(&:freeze).freeze

    module_function

    def not_an_issue(why)
      SkillSupport::Outcome.stop(NOT_AN_ISSUE, NOT_AN_ISSUE_MESSAGES.fetch(why))
    end

    def stop(reason, **fields)
      SkillSupport::Outcome.stop(reason, MESSAGES.fetch(reason), **fields)
    end

    # One entry of an ask's list; +details+ carries what the answer needs.
    def ask(reason, **details)
      { reason: reason, message: MESSAGES.fetch(reason), **details }
    end
  end
end
