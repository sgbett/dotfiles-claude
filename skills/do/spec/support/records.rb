# frozen_string_literal: true

require_relative '../../lib/do/records'

module Do
  module Testing
    # Builds the records preflight's pure modules work on. This repository
    # is example-owner/example-repo unless a spec says otherwise.
    module Records
      HOME = 'example-owner/example-repo'

      def home
        repository(HOME)
      end

      def repository(name_with_owner, visibility: 'PUBLIC')
        Do::Repository.new(name_with_owner: name_with_owner, owner: name_with_owner.split('/').first,
                           visibility: visibility)
      end

      def author(login = 'example-author', association: 'NONE', viewer: false)
        Do::Author.new(login: login, association: association, viewer_did_author: viewer)
      end

      # Edited by its author alone unless +edits+ says otherwise.
      def issue_record(number: 1, repository: home, author: author(), edits: nil, state: 'OPEN')
        Do::IssueRecord.new(id: "I_example#{number}", number: number, title: "Example issue #{number}", state: state,
                            author: author, repository: repository,
                            edits: edits || Do::Edits.new(logins: [author.login], complete: true))
      end

      def comment(body, author: author(), database_id: 1)
        Do::Comment.new(id: "IC_example#{database_id}", database_id: database_id, author: author, body: body)
      end
    end
  end
end
