# frozen_string_literal: true

require 'json'

module SkillSupport
  # What a skill script decided, in the shape the lead reads: one JSON object
  # whose first key is "status". This class is the only place a status is
  # mapped to an exit code; any other exit code means the tool failed.
  class Outcome
    EXIT_CODES = { 'proceed' => 0, 'stop' => 2, 'ask' => 3 }.freeze
    TOOL_FAILURE_EXIT_CODE = 1
    REASON = /\A[a-z][a-z0-9_]*\z/
    RESERVED_KEYS = %w[status reason message asks].freeze

    attr_reader :status

    # Nothing needs the lead. +fields+ (read:, summary:, session_only: ...)
    # follow "status" in the order given.
    def self.proceed(**fields)
      new('proceed', {}, fields)
    end

    # The run must not go on. +reason+ is one of the script's enum values;
    # +message+ must be built only from constants and validated identifiers.
    def self.stop(reason, message, **fields)
      new('stop', entry(reason, message), fields)
    end

    # The lead must ask the user. +asks+ is a list of hashes, each with
    # :reason and :message as for #stop, plus anything the answer needs, such
    # as the flag a yes passes back.
    def self.ask(asks, **fields)
      raise ArgumentError, 'an ask carries at least one question' unless asks.is_a?(Array) && !asks.empty?

      new('ask', { 'asks' => asks.map { |ask| question(ask) } }, fields)
    end

    def self.entry(reason, message)
      reason = reason.to_s
      raise ArgumentError, "a reason is a snake_case enum value, not #{reason.inspect}" unless REASON.match?(reason)
      raise ArgumentError, 'a message is a non-empty string' unless message.is_a?(String) && !message.strip.empty?

      { 'reason' => reason, 'message' => message }
    end

    def self.question(ask)
      raise ArgumentError, 'each ask is a hash with a reason and a message' unless ask.is_a?(Hash)

      ask = ask.transform_keys(&:to_s)
      entry(ask['reason'], ask['message']).merge(ask.except('reason', 'message'))
    end

    private_class_method :new, :entry, :question

    def initialize(status, head, fields)
      @status = status
      @body = head.merge(checked_fields(fields)).freeze
    end

    def exit_code
      EXIT_CODES.fetch(status)
    end

    # The reasons this outcome carries: a stop's, or each ask's.
    def reasons
      status == 'ask' ? @body['asks'].map { |ask| ask['reason'] } : [@body['reason']].compact
    end

    def to_h
      { 'status' => status }.merge(@body)
    end

    def to_json(*)
      JSON.generate(to_h)
    end

    private

    def checked_fields(fields)
      fields = fields.transform_keys(&:to_s)
      clashes = fields.keys & RESERVED_KEYS
      raise ArgumentError, "#{clashes.join(', ')} belong to the contract, not to a script" unless clashes.empty?

      fields
    end
  end
end
