# frozen_string_literal: true

module Do
  # The reference files that hold /do's rarer branches, which the lead reads
  # only when they apply.
  module ReferenceFiles
    RESUME = 'references/resume.md'
    OTHER_REPOSITORIES = 'references/other-repositories.md'
    GATE_BLOCK = 'references/gate-block.md'

    module_function

    # +resuming+: a ledger, trusted work already in flight, or an existing
    # branch to resume from; +other_repositories+: the parent or a sub-issue
    # lives in another repository, or the push remote is a fork; +open_gate+:
    # the gate file or the ledger has an open finding.
    def applicable(resuming:, other_repositories:, open_gate:)
      [(RESUME if resuming), (OTHER_REPOSITORIES if other_repositories), (GATE_BLOCK if open_gate)].compact
    end
  end
end
