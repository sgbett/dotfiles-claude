# frozen_string_literal: true

module Do
  # Who wrote something on GitHub: the login (nil for a deleted account), the
  # authorAssociation, which is relative to the repository it was written in,
  # and viewerDidAuthor.
  Author = Struct.new(:login, :association, :viewer_did_author, keyword_init: true) do
    # From a GraphQL node carrying author { login }, authorAssociation and
    # viewerDidAuthor.
    def self.from_node(node)
      new(login: node.dig('author', 'login'), association: node['authorAssociation'],
          viewer_did_author: node['viewerDidAuthor'])
    end
  end

  Repository = Struct.new(:name_with_owner, :owner, :visibility, keyword_init: true) do
    # GitHub compares owner and repository names ignoring case.
    def same_as?(other)
      name_with_owner.casecmp?(other.name_with_owner)
    end

    def same_owner_as?(other)
      owner.casecmp?(other.owner)
    end
  end

  # Everyone who changed an issue's body (userContentEdits) or title
  # (RenamedTitleEvent), nil for a deleted account, and whether both lists
  # came back whole.
  Edits = Struct.new(:logins, :complete, keyword_init: true)

  # The issue, its parent or a sub-issue. The title is GitHub text.
  IssueRecord = Struct.new(:id, :number, :title, :state, :author, :repository, :edits, keyword_init: true)

  # A comment on the issue. The body is GitHub text.
  Comment = Struct.new(:id, :database_id, :author, :body, keyword_init: true)

  Label = Struct.new(:id, :name, keyword_init: true)
  # +head_repository+ is the nameWithOwner of the repository its branch
  # lives in, nil when GitHub gives none (a deleted fork) or wasn't asked.
  PullRequest = Struct.new(:number, :author, :head_repository, keyword_init: true)
  Branch = Struct.new(:name, :pull_requests, keyword_init: true)
end
