# frozen_string_literal: true

module CopilotCheck
  module Testing
    # The files the lead hands promote-check, as it writes them for #18 of
    # sgbett/dotfiles-claude: the rules file, Phase 0's start file and a
    # round's bodies directory. GateCalls includes it, and gives the thread
    # fetch the bodies come from.
    module LeadFiles
      # The rules file, as the lead writes it: the rules say PRs open as
      # drafts and merging is the owner's, unless +rules+ say otherwise.
      def rules_file(**rules)
        rules = { draft_flow: true, merge_is_owners_step: true, expected_failures: [] }.merge(rules)
        sandbox.path('promotion-rules.json').tap { |path| File.write(path, JSON.generate(rules)) }
      end

      # Phase 0's pr0.json for #18 of this repository, a draft when the run
      # began unless +draft+ is false, in a run /do didn't chain unless
      # +chained+.
      def start_file(draft: true, chained: false, number: 18, repository: 'github.com/sgbett/dotfiles-claude')
        state = { 'number' => number, 'repository' => repository, 'baseRefName' => 'master',
                  'isCrossRepository' => false, 'isDraft' => draft, 'chained' => chained }
        sandbox.path('pr0.json').tap { |path| File.write(path, JSON.generate(state)) }
      end

      # A round's bodies directory as threads fetch writes it, with the body
      # of each review in +reviews+ (ids), Copilot's two of #18 unless given,
      # that the thread fetch +response+ gives.
      def bodies_directory(reviews = GateCalls::REVIEWS, response: threads_response)
        nodes = threads_pull_request(response)['reviews']['nodes']
        bodies = nodes.to_h { |node| node.values_at('databaseId', 'body') }
        sandbox.path('round-1').tap do |directory|
          FileUtils.mkdir_p(directory)
          reviews.each { |id| File.write(File.join(directory, "review-#{id}.md"), bodies.fetch(id)) }
        end
      end
    end
  end
end
