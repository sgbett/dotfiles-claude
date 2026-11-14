# frozen_string_literal: true

module Do
  module Reasons
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

    # Each stop and ask reason's message, keyed by the reason.
    MESSAGES = {
      host_not_logged_in: "gh has no account logged in to the issue's host (the host field), and /do sends a " \
                          'request only to a host the user has logged in to. Tell the user, who can log in with ' \
                          'gh auth login --hostname <host> and run /do again.',
      gate_advisory: 'An open security gate finding was answered advisory: the owner handles it through a ' \
                     'private security advisory, so this run stops. Push nothing.',
      no_origin: 'A bare number names an issue in the repository origin resolves to, and this directory has ' \
                 'no origin remote with a URL to resolve it through. A run never changes its issue, so tell ' \
                 'the user to run /do owner/repo#N instead, and end this run.',
      comments_truncated: 'The issue has more than 100 comments and none of the first 100 is a trusted ' \
                          'breakdown, so the ledger may be on a later page. Ask the user whether one exists.',
      untrusted_author_criteria: "The issue's or its parent's author isn't trusted, and the ledger records no " \
                                 'adopted acceptance criteria. Ask the user which criteria to adopt; once ' \
                                 'confirmed, record them in the ledger under "### Adopted acceptance criteria".',
      gate_record_missing: 'The ledger has an open gate line that the local gate file lacks. Ask the user ' \
                           'before building, pushing or any rewind.',
      remote_missing: "The push remote isn't a remote of this checkout, or has no push URL. #{RUN_FROM_A_CHECKOUT}",
      host_mismatch: "A URL the push remote pushes to isn't on the issue's host. #{RUN_FROM_A_CHECKOUT}",
      remote_unresolvable: "A URL the push remote pushes to doesn't resolve to a repository through GitHub " \
                           "(gh's answer is in session_only.stderr), and /do never reads the repository from " \
                           "the URL itself. #{RUN_FROM_A_CHECKOUT}",
      push_remote_not_this_repository: "The push remote pushes to a repository that is neither the issue's nor " \
                                       "a fork of it. #{RUN_FROM_A_CHECKOUT}",
      fork_not_writable: "The push remote pushes to a fork of the issue's repository on which the user has " \
                         'neither WRITE, MAINTAIN nor ADMIN (session_only.push_remote_forks), and /do resumes ' \
                         "from and pushes to a fork only with one of them. #{RUN_FROM_A_CHECKOUT}",
      pr_target_not_this_repository: 'The conventions send the pull request to a repository other than the ' \
                                     "issue's, and /do opens it only against the issue's repository. " \
                                     "#{RUN_FROM_A_CHECKOUT}",
      branch_is_base_or_default: "The branch the conventions name is the base or the repository's default " \
                                 'branch, and /do builds only on a branch of its own. Tell the user.',
      base_missing: "The base branch the conventions call for doesn't exist on the issue's repository. Tell " \
                    'the user: /do never creates or pushes a base branch.',
      checked_out_pr: 'The local branch is a checked-out pull request: its remote or pushRemote is a URL or ' \
                      'another remote, or it merges a refs/pull/ ref. /do never resumes on it, nor checks it ' \
                      'out, builds or tests it, and the push remote has no copy of the branch to resume from ' \
                      'instead. Tell the user, who can choose another branch.',
      remote_tips_differ: "The push remote's URLs disagree on the branch: they hold it at different commits, or " \
                          'only some of them hold it (branch.remote_tips, in the order of ' \
                          "session_only.push_urls), so /do can't tell which copy to resume from. Tell the " \
                          'user, who can bring them into line and run /do again.',
      untrusted_pull_request: "A pull request by an author the Trust rule doesn't trust is open on the branch " \
                              '(branch.pull_requests). /do never adopts it: tell the user, who can choose ' \
                              'another branch or deal with that pull request first.',
      local_branch_unpushed: 'The local branch was never pushed, or has commits the push remote lacks ' \
                             '(session_only.local_branch_commits). Show them to the user and ask whether to ' \
                             'resume on this branch; on a yes, run check again with accept_with added.',
      scripts_unreviewed: 'The checkout these scripts run from has changes under skills/do or ' \
                          'skills/_support or to the files at its root that pick their Ruby, or its HEAD ' \
                          "isn't in its default branch, so they may not be the reviewed scripts " \
                          '(session_only.scripts_changes). Ask the user whether to go on with them; on a yes, ' \
                          'run check again with accept_with added.',
      no_ledger: "None of the issue's first 100 comments is a ledger: none by a trusted author begins with " \
                 '<!-- do:breakdown -->. Nothing was written.',
      box_missing: 'Each box the call names must match exactly one top-level box outside code fences, and ' \
                   'those under missing match none or several (sub-issue also needs a plain item, with no box ' \
                   'for the sub-issue yet). Nothing was written.',
      body_changed: 'The body changed between the read and the write: someone else is editing it. Nothing was ' \
                    'written; /do can resume once they have finished.',
      untrusted_issue_author: "The issue's author isn't trusted, so record never edits its body. Nothing was " \
                              'written.',
      not_a_sub_issue: "That number isn't one of this issue's sub-issues in this repository, as GitHub lists " \
                       'them. Nothing was written.',
      untrusted_sub_issue: "That sub-issue's author isn't trusted, so its title never goes in the ledger. " \
                           'Nothing was written.',
      no_such_finding: 'The gate file has no finding with that G<k>. Nothing was written.',
      gate_answered: 'The gate file already holds a different answer from the owner for that finding, which ' \
                     'only the owner changes. Nothing was written.',
      gate_unanswered: 'This repository is public, and the gate file holds no answer from the owner for that ' \
                       'finding. Ask the user whether to fix it here or stop so the owner can use a private ' \
                       'security advisory, saying whether the flaw predates the branch; record the answer with ' \
                       'gate answer, then run gate publish again.',
      gate_line_missing: 'The ledger has no Gate line for that finding, so marking it would leave no record of ' \
                         'it there. Nothing was written.'
    }.transform_values(&:freeze).freeze
  end
end
