# frozen_string_literal: true

module CopilotCheck
  # What GitHub gave can't be read as the skill reads it, and the run must
  # stop for +reason+, one of Reasons' stops: Copilot's id has changed, the
  # filters no longer recognise its threads, or a list ran past its page.
  # Not a tool failure: the script catches it and stops with that reason.
  class Stop < StandardError
    attr_reader :reason

    def initialize(reason)
      @reason = reason
      super(reason.to_s)
    end
  end
end
