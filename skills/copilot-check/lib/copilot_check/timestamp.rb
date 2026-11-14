# frozen_string_literal: true

require 'time'

module CopilotCheck
  # A review's submittedAt as GitHub's GraphQL gives it, ISO 8601 in UTC, as
  # the high-water mark the lead passes back is too.
  module Timestamp
    # Older than any review, so that the first one Copilot makes is newer.
    EPOCH = '1970-01-01T00:00:00Z'
    FORMAT = /\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{1,9})?Z\z/

    module_function

    # +value+, unchanged. Raises InvalidIdentifier of +kind+ for anything
    # but such a timestamp.
    def check!(value, kind: :timestamp)
      raise SkillSupport::InvalidIdentifier.new(kind, value) unless value.is_a?(String) && FORMAT.match?(value)

      Time.iso8601(value)
      value
    rescue ArgumentError
      raise SkillSupport::InvalidIdentifier.new(kind, value)
    end

    # Whether timestamp +later+ is after timestamp +earlier+, compared as
    # times, not strings.
    def after?(later, earlier)
      Time.iso8601(later) > Time.iso8601(earlier)
    end
  end
end
