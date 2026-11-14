# frozen_string_literal: true

module Do
  # The Trust rule of /do's SKILL.md. Trusted means the viewer (the
  # authenticated user) or an authorAssociation of OWNER, MEMBER or
  # COLLABORATOR. For a parent or sub-issue in another repository, whose
  # authorAssociation is relative to that repository, only the viewer, or
  # OWNER or MEMBER when both repositories share an owner, counts, and only
  # if nobody but its author has edited its body or title. Whatever it can't
  # establish counts against trust.
  class Trust
    Verdict = Struct.new(:trusted, :reason, keyword_init: true)

    TRUSTED_HERE = %w[OWNER MEMBER COLLABORATOR].freeze
    TRUSTED_ELSEWHERE = %w[OWNER MEMBER].freeze
    # GitHub's CommentAuthorAssociation values; any other is unknown.
    ASSOCIATIONS = %w[COLLABORATOR CONTRIBUTOR FIRST_TIMER FIRST_TIME_CONTRIBUTOR MANNEQUIN MEMBER NONE OWNER].freeze
    REASONS = %i[viewer trusted_association no_author unknown_association untrusted_association different_owner
                 edited_by_others edits_unknown].freeze

    # +viewer+ is the authenticated user's login; +home+ is this repository,
    # the issue's.
    def initialize(viewer:, home:)
      @viewer = viewer
      @home = home
    end

    # For whatever was written in this repository: the issue, its comments,
    # pull requests into it, and a parent or sub-issue that lives here.
    def here(author)
      identity(author) || association(author, TRUSTED_HERE)
    end

    # For the issue's parent or one of its sub-issues, in any repository.
    def issue(record)
      return here(record.author) if record.repository.same_as?(@home)

      verdict = identity(record.author) || elsewhere(record)
      verdict.trusted ? (edits(record) || verdict) : verdict
    end

    private

    # The verdict the author's identity settles alone, or nil.
    def identity(author)
      return untrusted(:no_author) if author.login.nil?

      Verdict.new(trusted: true, reason: :viewer) if viewer?(author)
    end

    def elsewhere(record)
      return untrusted(:different_owner) unless record.repository.same_owner_as?(@home)

      association(record.author, TRUSTED_ELSEWHERE)
    end

    # nil when nobody but the author edited the body or title.
    def edits(record)
      logins = record.edits.logins
      return untrusted(:edits_unknown) unless record.edits.complete && logins.none?(&:nil?)

      untrusted(:edited_by_others) unless logins.all? { |login| login.casecmp?(record.author.login) }
    end

    def association(author, trusted)
      return untrusted(:unknown_association) unless ASSOCIATIONS.include?(author.association)
      return untrusted(:untrusted_association) unless trusted.include?(author.association)

      Verdict.new(trusted: true, reason: :trusted_association)
    end

    # viewerDidAuthor is GitHub's own answer; comparing logins is the
    # fallback for when it is missing.
    def viewer?(author)
      return author.viewer_did_author if [true, false].include?(author.viewer_did_author)

      !@viewer.nil? && author.login.casecmp?(@viewer)
    end

    def untrusted(reason)
      Verdict.new(trusted: false, reason: reason)
    end
  end
end
