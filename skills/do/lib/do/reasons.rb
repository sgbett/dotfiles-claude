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

    STOPS = [NOT_AN_ISSUE, GATE_ADVISORY].freeze
    ASKS = [NO_ORIGIN, COMMENTS_TRUNCATED, UNTRUSTED_AUTHOR_CRITERIA, GATE_RECORD_MISSING].freeze
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
                             'before building, pushing or any rewind.'
    }.freeze

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
