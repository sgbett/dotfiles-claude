# frozen_string_literal: true

require_relative 'reason_messages'

module RepoConsistency
  # Every reason git-settings can stop for, each with its message
  # (reason_messages.rb). A message is a constant, so no GitHub text can
  # reach one; the repository or file concerned travels beside it in
  # validated fields.
  module Reasons
    NO_REPOSITORIES = :no_repositories
    NOT_LOGGED_IN = :not_logged_in
    TEMPLATE_UNREADABLE = :template_unreadable
    REPOSITORY_UNREADABLE = :repository_unreadable

    # audit's whole enum: it never asks.
    AUDIT = [NO_REPOSITORIES, NOT_LOGGED_IN, TEMPLATE_UNREADABLE, REPOSITORY_UNREADABLE].freeze
    ALL = AUDIT

    module_function

    def stop(reason, **fields)
      SkillSupport::Outcome.stop(reason, MESSAGES.fetch(reason), **fields)
    end
  end
end
