# frozen_string_literal: true

module SkillSupport
  # Reads a file as it stands at a ref through GitHub's contents API, rather
  # than from a checkout the change under review can alter.
  class RepositoryFiles
    # A 404 for a missing ref says "No commit found for the ref ..."; only this
    # message means the path is absent.
    ABSENT_MESSAGE = 'Not Found'
    # The contents API lists at most 1,000 entries of a directory.
    LISTING_LIMIT = 1000
    DOT_SEGMENTS = %w[. ..].freeze
    CONTROL_CHARACTER = /[[:cntrl:]]/

    # +github+ is the Gh to read through, which fixes the host.
    def initialize(github)
      @github = github
    end

    # Returns the file at +path+ in +repository+ ("owner/repo") at +ref+ as a
    # UTF-8 String; a directory's listing (the API's entry hashes, with
    # "name", "path" and "type") so callers can read it file by file; or nil
    # when GitHub answers 404 Not Found. That answer also comes when the
    # repository itself isn't visible, so confirm the repository separately.
    # Any other failure raises, as does a symlink, a submodule, a file too
    # large for the API, or a listing that may be truncated.
    def read(repository, path, ref:)
      content = @github.api(contents_path(repository, path), fields: { 'ref' => checked_ref(ref) })
      content.is_a?(Array) ? listing(content, path) : decoded_file(content, path)
    rescue GhError => e
      raise unless absent?(e)
    end

    private

    def contents_path(repository, path)
      "repos/#{Identifiers.repository!(repository)}/contents/#{escaped_path(path)}"
    end

    def escaped_path(path)
      segments = path.is_a?(String) ? path.split('/', -1) : []
      if segments.empty? || segments.any? { |segment| segment.empty? || DOT_SEGMENTS.include?(segment) }
        raise InvalidIdentifier.new(:file_path, path)
      end

      segments.map { |segment| Gh.path_segment(segment) }.join('/')
    end

    # An empty ref would make the API read the default branch instead.
    def checked_ref(ref)
      raise InvalidIdentifier.new(:ref, ref) unless ref.is_a?(String) && !ref.empty? && !CONTROL_CHARACTER.match?(ref)

      ref
    end

    def absent?(error)
      error.http_status == 404 && error.api_message == ABSENT_MESSAGE
    end

    def listing(entries, path)
      raise UnexpectedResponse, "#{path} may have more entries than the API lists" if entries.length >= LISTING_LIMIT

      entries
    end

    def decoded_file(content, path)
      raise UnexpectedResponse, "#{path} is not a file" unless content.is_a?(Hash) && content['type'] == 'file'
      unless content['encoding'] == 'base64' && content['content'].is_a?(String)
        raise UnexpectedResponse, "#{path} came back without its content, as files over 1 MB do"
      end

      content['content'].unpack1('m').force_encoding(Encoding::UTF_8)
    end
  end
end
