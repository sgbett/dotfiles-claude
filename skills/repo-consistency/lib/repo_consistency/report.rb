# frozen_string_literal: true

module RepoConsistency
  # The audit's outcome: each repository's default branch, tier, difference
  # and drift, in the order given, under a summary of how many have drift.
  class Report
    Entry = Struct.new(:repository, :default_branch, :tier, :difference, :drift, keyword_init: true)

    def initialize
      @entries = []
    end

    # +actual+ is the repository's Projection, +drift+ its lines.
    def add(repository, actual, drift)
      @entries << Entry.new(repository: repository, default_branch: actual.default_branch, tier: actual.tier,
                            difference: actual.difference, drift: drift)
    end

    def outcome
      with_drift = @entries.count { |entry| !entry.drift.empty? }
      SkillSupport::Outcome.proceed(summary: { repositories: @entries.length, with_drift: with_drift,
                                               clean: @entries.length - with_drift },
                                    repositories: @entries.map(&:to_h))
    end
  end
end
