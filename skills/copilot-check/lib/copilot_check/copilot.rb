# frozen_string_literal: true

module CopilotCheck
  # Copilot's account, matched by its id, never its login (SKILL.md's
  # identity table): the login differs by surface, and the bare GraphQL login
  # is also an unrelated organisation's.
  module Copilot
    BOT_ID = 'BOT_kgDOCnlnWA'
    # What GraphQL's reviews(author:) takes; it only narrows the list, and
    # the id check is the match.
    REVIEWER_LOGIN = 'copilot-pull-request-reviewer[bot]'
    # GraphQL's login for Copilot as a comment's author.
    COMMENT_LOGIN = 'copilot-pull-request-reviewer'
    BOT_TYPE = 'Bot'

    module_function

    # Whether GraphQL +node+ (a review or comment) has Copilot as its author.
    def authored?(node)
      !node.nil? && node.dig('author', 'id') == BOT_ID
    end

    # Whether a bot wrote +comment+ under Copilot's comment login, whatever
    # its id.
    def comment_login?(comment)
      author = comment && comment['author']
      author.is_a?(Hash) && author['__typename'] == BOT_TYPE && author['login'] == COMMENT_LOGIN
    end
  end
end
