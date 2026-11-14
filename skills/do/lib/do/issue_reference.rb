# frozen_string_literal: true

module Do
  # Parses the issue /do was given: a number, which names an issue in the
  # repository origin resolves to; owner/repo#N, on github.com; or an issue
  # URL, https://<host>/<owner>/<repo>/issues/<N>. Writes the canonical form
  # every call after `preflight facts` takes.
  module IssueReference
    DEFAULT_HOST = 'github.com'
    # A bare number may come with its "#", as in /do #42.
    NUMBER = /\A#?(?<number>[0-9]+)\z/
    SHORT = %r{\A(?<repository>[^/#]+/[^/#]+)#(?<number>[0-9]+)\z}
    URL = %r{\Ahttps://(?<host>[^/]+)/(?<repository>[^/]+/[^/]+)/issues/(?<number>[0-9]+)\z}

    # +host+ and +repository+ are nil for a bare number until origin names them.
    Reference = Struct.new(:host, :repository, :number, keyword_init: true) do
      def bare?
        repository.nil?
      end
    end

    module_function

    # The Reference +text+ names, or nil when it isn't an issue reference.
    def parse(text)
      return unless text.is_a?(String) && !text.start_with?('-')

      bare(text) || short(text) || url(text)
    rescue SkillSupport::InvalidIdentifier
      nil
    end

    # owner/repo#N on github.com, the issue's URL on any other host: never a
    # bare number, which origin could later resolve elsewhere. Each part is
    # validated, as the lead puts the result on its command lines.
    def canonical(host, repository, number)
      host = SkillSupport::Identifiers.host!(host)
      repository = SkillSupport::Identifiers.repository!(repository)
      number = SkillSupport::Identifiers.issue_number!(number)
      host == DEFAULT_HOST ? "#{repository}##{number}" : "https://#{host}/#{repository}/issues/#{number}"
    end

    def bare(text)
      match = NUMBER.match(text)
      Reference.new(number: SkillSupport::Identifiers.issue_number!(match[:number])) if match
    end

    def short(text)
      match = SHORT.match(text)
      reference(DEFAULT_HOST, match) if match
    end

    def url(text)
      match = URL.match(text)
      reference(SkillSupport::Identifiers.host!(match[:host]), match) if match
    end

    def reference(host, match)
      Reference.new(host: host, repository: SkillSupport::Identifiers.repository!(match[:repository]),
                    number: SkillSupport::Identifiers.issue_number!(match[:number]))
    end

    private_class_method :bare, :short, :url, :reference
  end
end
