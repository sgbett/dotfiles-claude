# frozen_string_literal: true

module RepoConsistency
  module Reasons
    # Each stop reason's message, keyed by the reason.
    MESSAGES = {
      no_repositories: 'No repository was named. Tell the user that git-settings audit takes one or more ' \
                       'owner/repo names, as the discovery commands list them.',
      not_logged_in: 'gh has no account logged in to the host (the host field), and the audit sends a request only ' \
                     'to a host the user has logged in to. Tell the user, who can log in with gh auth login ' \
                     '--hostname <host> and run the audit again.',
      template_unreadable: 'A file of the template directory (the file field) is missing or is not JSON, so there ' \
                           'is nothing to compare against. Tell the user: the template is profiles/git-workflow in ' \
                           'sgbett/dotfiles-claude, and --template-dir names another copy.',
      repository_unreadable: 'gh cannot read the repository (the repository field): it does not exist, or the ' \
                             'account has no access to it. Tell the user to leave it out of the list or fix the ' \
                             'access, then run the audit again.'
    }.transform_values(&:freeze).freeze
  end
end
