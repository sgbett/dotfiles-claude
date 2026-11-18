# frozen_string_literal: true

require_relative 'repository_state'
require_relative 'vendored_paths'

module RepoConsistency
  # gh cannot read the repository itself: 404 or 403 on repos/{owner}/{repo}.
  class RepositoryUnreadable < SkillSupport::Error
    attr_reader :repository

    def initialize(repository, error)
      @repository = repository
      super("#{repository}: #{error.message}")
    end
  end

  # Reads what the audit compares for one repository, in a fixed order so
  # that a spec can match every call: the repository, the rules in force on
  # its default branch, its rulesets and each one's detail, its classic
  # protection, then the files a collaborative repository vendors. Only here
  # is a 404 on the protection read taken to mean none, and a 403 naming
  # the plan taken to mean rulesets are unavailable rather than failed.
  class RepositoryReader
    PER_PAGE = 100
    NOT_PROTECTED = 'Branch not protected'
    # GitHub's 403 on a private repository whose plan lacks rulesets and
    # branch protection: "Upgrade to GitHub Pro or make this repository
    # public to enable this feature."
    PLAN_MESSAGE = /upgrade to/i
    UNREADABLE_STATUSES = [403, 404].freeze

    # +flags+ are the repository fields the template sets, read with the
    # repository.
    def self.read(github, repository, flags:)
      new(github, repository, flags: flags).read
    end

    def initialize(github, repository, flags:)
      @github = github
      @repository = repository
      @flags = flags
      @path = "repos/#{repository}"
      @rulesets_available = true
    end

    def read
      facts = repository_facts
      @branch = branch!(facts['default_branch'])
      rules = effective_rules
      rulesets = ruleset_details
      protection = classic_protection
      RepositoryState.new(repository: @repository, default_branch: @branch, flags: facts.slice(*@flags), rules: rules,
                          rulesets: rulesets, protection: protection, rulesets_available: @rulesets_available,
                          files: files)
    end

    private

    def repository_facts
      @github.api(@path)
    rescue SkillSupport::GhError => e
      raise RepositoryUnreadable.new(@repository, e) if UNREADABLE_STATUSES.include?(e.http_status)

      raise
    end

    # The default branch's name goes into API paths, so it takes only the
    # characters a branch name may.
    def branch!(name)
      raise SkillSupport::UnexpectedResponse, "#{@repository} named no default branch" unless name.is_a?(String)
      return name if SkillSupport::Identifiers::BRANCH_CHARACTERS.match?(name)

      raise SkillSupport::InvalidIdentifier.new(:branch, name)
    end

    def effective_rules
      unless_plan_forbids([]) { complete_list("#{@path}/rules/branches/#{SkillSupport::Gh.path_segment(@branch)}") }
    end

    def ruleset_details
      unless_plan_forbids([]) { complete_list("#{@path}/rulesets") }
        .map { |ruleset| @github.api("#{@path}/rulesets/#{ruleset_id!(ruleset)}") }
    end

    def ruleset_id!(ruleset)
      id = ruleset['id'] if ruleset.is_a?(Hash)
      raise SkillSupport::UnexpectedResponse, "a ruleset of #{@repository} has no integer id" unless id.is_a?(Integer)

      id
    end

    def classic_protection
      unless_plan_forbids(nil) { @github.api("#{@path}/branches/#{SkillSupport::Gh.path_segment(@branch)}/protection") }
    rescue SkillSupport::GhError => e
      raise unless e.http_status == 404 && e.api_message == NOT_PROTECTED
    end

    # Yields for a read a repository on a free plan answers with the 403
    # naming the upgrade; the audit then goes on with +none+ and reports the
    # plan once, as drift.
    def unless_plan_forbids(none)
      yield
    rescue SkillSupport::GhError => e
      raise unless e.http_status == 403 && PLAN_MESSAGE.match?(e.api_message.to_s)

      @rulesets_available = false
      none
    end

    # A list read in one page, failing rather than reporting a cut-off one.
    def complete_list(path)
      entries = @github.api(path, fields: { 'per_page' => PER_PAGE.to_s })
      raise SkillSupport::UnexpectedResponse, "#{path} returned something other than a list" unless entries.is_a?(Array)
      return entries if entries.length < PER_PAGE

      raise SkillSupport::IncompleteResults, "#{path} has more entries than one page lists"
    end

    def files
      reader = SkillSupport::RepositoryFiles.new(@github)
      VendoredPaths::ALL.to_h do |file|
        content = reader.read(@repository, file, ref: @branch)
        raise SkillSupport::UnexpectedResponse, "#{file} in #{@repository} is a directory" if content.is_a?(Array)

        [file, content]
      end
    end
  end
end
