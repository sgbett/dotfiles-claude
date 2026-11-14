# frozen_string_literal: true

require_relative '../lib/do/trust'
require_relative 'support/records'

RSpec.describe Do::Trust do
  include Do::Testing::Records

  subject(:trust) { described_class.new(viewer: 'example-viewer', home: home) }

  let(:elsewhere) { repository('example-owner/other-repo') }
  let(:other_owner) { repository('example-stranger/their-repo') }

  def verdict(result)
    [result.trusted, result.reason]
  end

  describe '#here, for what was written in this repository' do
    it 'trusts the viewer by viewerDidAuthor, whatever the association' do
      expect(verdict(trust.here(author('someone', association: 'NONE', viewer: true)))).to eq([true, :viewer])
    end

    it 'falls back to comparing logins, ignoring case, only when viewerDidAuthor is missing' do
      expect(verdict(trust.here(author('Example-Viewer', viewer: nil)))).to eq([true, :viewer])
      expect(verdict(trust.here(author('example-viewer', viewer: false)))).to eq([false, :untrusted_association])
    end

    it 'trusts OWNER, MEMBER and COLLABORATOR' do
      %w[OWNER MEMBER COLLABORATOR].each do |association|
        expect(verdict(trust.here(author(association: association)))).to eq([true, :trusted_association]), association
      end
    end

    it "doesn't trust any other association GitHub has" do
      %w[CONTRIBUTOR FIRST_TIMER FIRST_TIME_CONTRIBUTOR MANNEQUIN NONE].each do |association|
        expect(verdict(trust.here(author(association: association))))
          .to eq([false, :untrusted_association]), association
      end
    end

    it 'fails closed on an association it does not know, or none' do
      ['ADMIN', 'owner', '', nil].each do |association|
        expect(verdict(trust.here(author(association: association))))
          .to eq([false, :unknown_association]), association.inspect
      end
    end

    it 'fails closed on a deleted author, even one marked as the viewer' do
      expect(verdict(trust.here(author(nil, association: 'OWNER', viewer: true)))).to eq([false, :no_author])
    end
  end

  describe '#issue, for the parent or a sub-issue' do
    it 'applies the rule for this repository to one that lives here, compared ignoring case' do
      record = issue_record(repository: repository('Example-Owner/Example-Repo'),
                            author: author(association: 'COLLABORATOR'),
                            edits: Do::Edits.new(logins: ['example-stranger'], complete: false))

      expect(verdict(trust.issue(record))).to eq([true, :trusted_association])
    end

    it 'trusts the viewer elsewhere when nobody else edited it' do
      record = issue_record(repository: other_owner, author: author('example-viewer', viewer: true))

      expect(verdict(trust.issue(record))).to eq([true, :viewer])
    end

    it 'trusts OWNER or MEMBER elsewhere only when both repositories share an owner, ignoring case' do
      shared = repository('EXAMPLE-OWNER/other-repo')

      %w[OWNER MEMBER].each do |association|
        expect(verdict(trust.issue(issue_record(repository: shared, author: author(association: association)))))
          .to eq([true, :trusted_association]), association
        expect(verdict(trust.issue(issue_record(repository: other_owner, author: author(association: association)))))
          .to eq([false, :different_owner]), association
      end
    end

    it "doesn't trust a COLLABORATOR elsewhere, whose association is that repository's" do
      record = issue_record(repository: elsewhere, author: author(association: 'COLLABORATOR'))

      expect(verdict(trust.issue(record))).to eq([false, :untrusted_association])
    end

    it 'fails closed on an unknown association elsewhere' do
      record = issue_record(repository: elsewhere, author: author(association: nil))

      expect(verdict(trust.issue(record))).to eq([false, :unknown_association])
    end

    it 'fails closed on a deleted author elsewhere' do
      expect(verdict(trust.issue(issue_record(repository: elsewhere, author: author(nil, association: 'OWNER')))))
        .to eq([false, :no_author])
    end

    it "doesn't trust one whose body or title someone else changed, the viewer's included" do
      [author('example-author', association: 'OWNER'), author('example-viewer', viewer: true)].each do |writer|
        edits = Do::Edits.new(logins: [writer.login, 'example-stranger'], complete: true)

        expect(verdict(trust.issue(issue_record(repository: elsewhere, author: writer, edits: edits))))
          .to eq([false, :edited_by_others]), writer.login
      end
    end

    it 'counts edits by its author, in any case, as no edit' do
      edits = Do::Edits.new(logins: %w[example-author EXAMPLE-AUTHOR], complete: true)
      record = issue_record(repository: elsewhere, author: author(association: 'MEMBER'), edits: edits)

      expect(verdict(trust.issue(record))).to eq([true, :trusted_association])
    end

    it 'fails closed when the editors or renamers came back cut off, or an editor has no login' do
      [Do::Edits.new(logins: ['example-author'], complete: false),
       Do::Edits.new(logins: ['example-author', nil], complete: true)].each do |edits|
        record = issue_record(repository: elsewhere, author: author(association: 'OWNER'), edits: edits)

        expect(verdict(trust.issue(record))).to eq([false, :edits_unknown]), edits.inspect
      end
    end
  end
end
