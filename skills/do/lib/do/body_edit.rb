# frozen_string_literal: true

module Do
  # The body changed between the read a change was made from and the write:
  # someone else is editing it. Not a tool failure: `record` stops with
  # Reasons::BODY_CHANGED.
  class BodyChanged < StandardError; end

  # A body on GitHub that record edits in place, the issue's or the ledger
  # comment's, through REST. One writer per body: a change is made from the
  # body as it was read, so the body is read again just before the write,
  # which goes ahead only if nothing changed in between, and read back after
  # it.
  class BodyEdit
    # +github+ is the SkillSupport::Gh for the issue's host and +repository+
    # its "owner/repo".
    def self.issue(github, repository, number)
      new(github, "repos/#{SkillSupport::Identifiers.repository!(repository)}/issues/" \
                  "#{SkillSupport::Identifiers.issue_number!(number)}")
    end

    def self.comment(github, repository, comment_id)
      new(github, "repos/#{SkillSupport::Identifiers.repository!(repository)}/issues/comments/" \
                  "#{SkillSupport::Identifiers.comment_id!(comment_id)}")
    end

    def initialize(github, path)
      @github = github
      @path = path
    end

    # The body as GitHub has it now, "" for none.
    def read
      response = @github.api(@path)
      body = response['body'] if response.is_a?(Hash)
      unless response.is_a?(Hash) && response.key?('body') && (body.nil? || body.is_a?(String))
        raise SkillSupport::UnexpectedResponse, "#{@path} came back without a body"
      end

      body.to_s
    end

    # Writes +after+, made from +before+. Raises BodyChanged, writing
    # nothing, when the body no longer reads as +before+, and
    # UnexpectedResponse when what was written doesn't read back.
    def write(before, after)
      raise BodyChanged unless read == before

      @github.api(@path, method: 'PATCH', body: { 'body' => after })
      raise SkillSupport::UnexpectedResponse, "#{@path} doesn't read back as written" unless read == after
    end
  end
end
