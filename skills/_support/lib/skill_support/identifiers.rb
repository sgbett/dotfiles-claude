# frozen_string_literal: true

module SkillSupport
  # Checks for every identifier a script accepts as an argument or builds a
  # path, URL or command from. Each check returns the value in canonical form
  # or raises InvalidIdentifier; none accepts an empty value or one that
  # starts with "-", which a command would read as an option.
  module Identifiers
    # GitHub logins are letters, digits and hyphens; Enterprise Managed Users
    # add an underscore before their enterprise's short code.
    OWNER = /[A-Za-z0-9][A-Za-z0-9_-]{0,38}/
    REPOSITORY_NAME = /[A-Za-z0-9._-]{1,100}/
    REPOSITORY = %r{\A(?<owner>#{OWNER})/(?<name>#{REPOSITORY_NAME})\z}
    ISSUE_NUMBER = /\A[1-9][0-9]{0,9}\z/
    # Path-safe on purpose: a node id names the local gate file, so the "+" and
    # "/" of GitHub's legacy base64 ids are refused rather than escaped.
    NODE_ID = /\A[A-Za-z0-9_=][A-Za-z0-9_=-]{0,99}\z/
    COMMENT_ID = /\A[1-9][0-9]{0,19}\z/
    # Whole object names only, SHA-1 or SHA-256: an abbreviation can match
    # another commit later.
    COMMIT_SHA = /\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z/i
    HOST_LABEL = /[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?/
    HOST = /\A#{HOST_LABEL}(?:\.#{HOST_LABEL})+\z/
    HOST_MAX_LENGTH = 253
    DOT_SEGMENTS = %w[. ..].freeze
    CONTROL_CHARACTER = /[[:cntrl:]]/

    module_function

    # "owner/repo", unchanged.
    def repository!(value)
      match = REPOSITORY.match(string!(:repository, value))
      raise InvalidIdentifier.new(:repository, value) if match.nil? || DOT_SEGMENTS.include?(match[:name])

      value
    end

    # An issue or pull request number, as an Integer.
    def issue_number!(value)
      Integer(matching!(:issue_number, ISSUE_NUMBER, value.is_a?(Integer) ? value.to_s : value), 10)
    end

    # A GraphQL node id, unchanged.
    def node_id!(value)
      matching!(:node_id, NODE_ID, value)
    end

    # A REST comment id (GraphQL's databaseId), as an Integer.
    def comment_id!(value)
      Integer(matching!(:comment_id, COMMENT_ID, value.is_a?(Integer) ? value.to_s : value), 10)
    end

    # A commit's full object name, lower-cased.
    def commit_sha!(value)
      matching!(:commit_sha, COMMIT_SHA, value).downcase
    end

    # A host name such as "github.com", lower-cased. No scheme, port or path.
    def host!(value)
      host = matching!(:host, HOST, value)
      raise InvalidIdentifier.new(:host, value) if host.length > HOST_MAX_LENGTH

      host.downcase
    end

    # A branch name git accepts, unchanged. git check-ref-format --branch also
    # expands "@{-1}" to the previous branch, so anything it rewrites is refused.
    def branch!(value, runner: CommandRunner.new)
      name = string!(:branch, value)
      raise InvalidIdentifier.new(:branch, value) if CONTROL_CHARACTER.match?(name)

      result = runner.run(['git', 'check-ref-format', '--branch', name])
      raise InvalidIdentifier.new(:branch, value) unless result.success? && result.stdout.chomp == name

      name
    end

    def matching!(kind, pattern, value)
      raise InvalidIdentifier.new(kind, value) unless pattern.match?(string!(kind, value))

      value
    end

    def string!(kind, value)
      raise InvalidIdentifier.new(kind, value) unless value.is_a?(String) && !value.empty? && !value.start_with?('-')

      value
    end

    private_class_method :matching!, :string!
  end
end
