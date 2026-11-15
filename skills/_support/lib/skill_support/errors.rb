# frozen_string_literal: true

require 'json'
require_relative 'remote_url'

module SkillSupport
  # Base of every failure the library anticipates. A script reports any of
  # them as a tool failure (exit 1); see Cli.
  class Error < StandardError; end

  # A value that is not a safe identifier of the expected kind. The message
  # names only the kind, so an unchecked value never reaches script output;
  # #value keeps it for diagnostics.
  class InvalidIdentifier < Error
    attr_reader :kind, :value

    def initialize(kind, value)
      @kind = kind
      @value = value
      super("invalid #{kind}")
    end
  end

  # The command to run is not installed, or not on PATH.
  class CommandNotFound < Error
    attr_reader :command

    def initialize(command)
      @command = command
      super("#{command} is not installed or not on PATH")
    end
  end

  # gh exited non-zero. Carries what it printed, so a caller can tell one
  # HTTP answer from another (see #http_status and #api_message).
  class GhError < Error
    HTTP_STATUS = /\(HTTP (\d{3})\)/

    attr_reader :arguments, :exit_status, :stdout, :stderr

    # The message names the arguments with any URL's credentials masked, as
    # a remote URL can carry a token and a tool failure prints the message.
    def initialize(arguments, result, message = nil)
      @arguments = arguments
      @exit_status = result.exit_status
      @stdout = result.stdout
      @stderr = result.stderr
      printed = arguments.map { |argument| RemoteUrl.redacted(argument) }.join(' ')
      super(message || "gh #{printed} exited #{exit_status}: #{stderr.strip}")
    end

    # The HTTP status gh reported on stderr, as in "gh: Not Found (HTTP 404)",
    # or nil when the failure was not an HTTP answer.
    def http_status
      stderr[HTTP_STATUS, 1]&.to_i
    end

    # The "message" of the JSON error body gh printed on stdout, or nil.
    def api_message
      body = JSON.parse(stdout)
      body['message'] if body.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end
  end

  # A GraphQL response carried errors. GitHub can return them alongside
  # partial data, which must never be read as a complete answer.
  class GraphqlError < GhError
    attr_reader :errors

    def initialize(arguments, result, errors)
      @errors = errors
      super(arguments, result, "GraphQL errors: #{describe(errors)}")
    end

    private

    def describe(errors)
      Array(errors).map { |error| error.is_a?(Hash) ? error['message'] : error.to_s }.join('; ')
    end
  end

  # gh succeeded, but what it returned can't be used as asked: not JSON, no
  # data, or not the kind of content the caller needs.
  class UnexpectedResponse < Error; end

  # A GraphQL connection has more entries than the page that came back, or a
  # REST list came back as a full page, which may go on to another.
  class IncompleteResults < Error; end
end
