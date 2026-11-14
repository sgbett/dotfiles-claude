# frozen_string_literal: true

module Do
  # A security gate finding's state, as written in the ledger's
  # "Gate G<k>: <state>" lines and the gate file's "## G<k>: <state>"
  # headings.
  module GateState
    OPEN = 'open'
    CLOSED = ['fixed', 'user decided'].freeze

    module_function

    # Anything not exactly a closed state reads as open, so a typo can never
    # clear a finding.
    def parse(text)
      state = text.strip
      CLOSED.include?(state) ? state : OPEN
    end
  end
end
