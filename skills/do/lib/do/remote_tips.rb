# frozen_string_literal: true

require_relative 'git'

module Do
  # Which of the push remote's branch tips are commits here, for log to
  # measure a local branch against. Those that aren't are fetched by name
  # through a push URL, as the base is, unless more than MAX_FETCHED are
  # missing: a fork with many branches this checkout never fetched costs at
  # most a bounded fetch.
  class RemoteTips
    MAX_FETCHED = 50

    # +url+ is the push URL to fetch through.
    def initialize(git, url:)
      @git = git
      @url = url
    end

    # The commits among +tips+, full object names, that are here once those
    # missing are fetched. A tip left out, as when there are too many or the
    # fetch fails, leaves the commits only it holds unmeasured.
    def here(tips)
      found = commits(tips)
      missing = tips - found
      found += commits(missing) if fetchable?(missing) && fetched?(missing)
      found
    end

    private

    # cat-file prints a line for each name it reads, "<name> missing" for
    # an object that isn't here.
    def commits(tips)
      return [] if tips.empty?

      types = @git.output('cat-file', '--batch-check=%(objecttype)', stdin: tips.map { |tip| "#{tip}\n" }.join)
      tips.zip(types.lines(chomp: true)).filter_map { |tip, type| tip if type == 'commit' }
    end

    def fetchable?(tips)
      !tips.empty? && tips.length <= MAX_FETCHED
    end

    def fetched?(tips)
      @git.run(*Git::NO_HOOKS_OR_FSMONITOR, 'fetch', '--no-tags', '--quiet', @url, *tips)
      true
    rescue GitError
      false
    end
  end
end
