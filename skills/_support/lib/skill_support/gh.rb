# frozen_string_literal: true

require 'json'

module SkillSupport
  # Calls gh against one host and returns parsed JSON, so a failed call or an
  # unusable answer is an exception, never data. Every call names its host:
  # `gh api` through --hostname, `gh repo view` through the URL it is given.
  class Gh
    HTTP_METHODS = %w[GET POST PATCH PUT DELETE].freeze
    API_PATH = %r{\A[A-Za-z0-9_.~%][A-Za-z0-9_.~%-]*(?:/[A-Za-z0-9_.~%-]+)*\z}
    RESERVED_BYTE = /[^A-Za-z0-9._~-]/n
    DOT_SEGMENTS = %w[. ..].freeze
    FIELD_NAME = /\A[A-Za-z_][A-Za-z0-9_]*\z/
    JSON_FIELD = /\A[a-z][A-Za-z]*\z/
    # The URL forms gh itself reads as a URL rather than as OWNER/REPO.
    REPOSITORY_URL = %r{\A(?:(?:https?|ssh|git|git\+ssh|git\+https)://|git@)[^[:space:][:cntrl:]]+\z}

    attr_reader :host

    # +value+ as one segment of an #api path: every byte outside the
    # unreserved characters as %XX, so a "/" in it can't start another.
    def self.path_segment(value)
      value.b.gsub(RESERVED_BYTE) { |byte| format('%%%02X', byte.ord) }
    end

    def initialize(host:, runner: CommandRunner.new)
      @host = Identifiers.host!(host)
      @runner = runner
    end

    # Runs `gh ARGUMENTS` and returns its parsed JSON. The arguments must name
    # the host themselves (a URL, or -R HOST/OWNER/REPO); #api, #graphql and
    # #repo_view do that already. Raises GhError on a non-zero exit and
    # UnexpectedResponse when the output isn't JSON.
    def json(arguments, stdin: nil)
      result = @runner.run(['gh', *arguments], stdin: stdin)
      raise GhError.new(arguments, result) unless result.success?

      parse(arguments, result.stdout)
    end

    # A REST call. A GET sends +fields+ as its query string through -f, which
    # URL-encodes each value; any other method sends +body+ as JSON on stdin.
    # +path+ is relative ("repos/OWNER/REPO/..."), its segments already
    # percent-encoded, with no query string, fragment or dot segment.
    def api(path, method: 'GET', fields: {}, body: nil)
      json(api_arguments(path, method, fields, body), stdin: body && JSON.generate(body))
    end

    # Runs a GraphQL query, its +variables+ sent beside it rather than spliced
    # in, and returns the response's data. Raises GraphqlError whenever the
    # response carries errors, even with data alongside them.
    def graphql(query, variables = {})
      arguments = ['api', 'graphql', '--hostname', host, '--input', '-']
      result = @runner.run(['gh', *arguments], stdin: JSON.generate('query' => query, 'variables' => variables))
      response = parse_or_nil(result.stdout)
      errors = response['errors'] if response.is_a?(Hash)
      raise GraphqlError.new(arguments, result, errors) unless errors.nil? || errors == []
      raise GhError.new(arguments, result) unless result.success?

      graphql_data(response)
    end

    # `gh repo view URL --json FIELDS`. A bare OWNER/REPO, or a local remote
    # path shaped like one, would be looked up on github.com, so only a URL is
    # accepted.
    def repo_view(url, fields)
      raise InvalidIdentifier.new(:repository_url, url) unless url.is_a?(String) && REPOSITORY_URL.match?(url)
      raise ArgumentError, 'name at least one JSON field' unless json_fields?(fields)

      json(['repo', 'view', url, '--json', fields.join(',')])
    end

    # Whether gh has an active account on the host with a working token; gh
    # sends nothing to a host it has no account on. --active leaves out the
    # host's other accounts, which no call uses.
    def logged_in?
      @runner.run(['gh', 'auth', 'status', '--active', '--hostname', host]).success?
    end

    private

    def api_arguments(path, method, fields, body)
      check_api_path(path)
      check_payload(method, fields, body)
      ['api', '--hostname', host, '-X', method, path, *field_arguments(fields), *(body ? %w[--input -] : [])]
    end

    def check_api_path(path)
      raise ArgumentError, 'GraphQL goes through #graphql, which checks its errors' if path == 'graphql'
      return if path.is_a?(String) && API_PATH.match?(path) && !path.split('/').intersect?(DOT_SEGMENTS)

      raise ArgumentError, 'an API path is relative and percent-encoded, with no query, fragment or dot segment'
    end

    def check_payload(method, fields, body)
      raise ArgumentError, "unsupported HTTP method #{method.inspect}" unless HTTP_METHODS.include?(method)
      raise ArgumentError, 'a GET sends fields, never a body' if method == 'GET' && body
      raise ArgumentError, "a #{method} sends a body, never fields" if method != 'GET' && !fields.empty?
    end

    def field_arguments(fields)
      fields.flat_map do |name, value|
        raise ArgumentError, "invalid field name #{name.inspect}" unless FIELD_NAME.match?(name.to_s)
        raise ArgumentError, "field #{name} must be a string" unless value.is_a?(String)

        ['-f', "#{name}=#{value}"]
      end
    end

    def json_fields?(fields)
      fields.is_a?(Array) && !fields.empty? && fields.all? { |field| field.is_a?(String) && JSON_FIELD.match?(field) }
    end

    def parse(arguments, output)
      JSON.parse(output)
    rescue JSON::ParserError
      raise UnexpectedResponse, "gh #{arguments.first(2).join(' ')} printed something other than JSON"
    end

    def parse_or_nil(output)
      JSON.parse(output)
    rescue JSON::ParserError
      nil
    end

    def graphql_data(response)
      data = response['data'] if response.is_a?(Hash)
      raise UnexpectedResponse, 'the GraphQL response carried no data' unless data.is_a?(Hash)

      data
    end
  end
end
