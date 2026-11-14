# frozen_string_literal: true

require_relative '../lib/do/ledger'
require_relative 'support/records'

RSpec.describe Do::Ledger do
  include Do::Testing::Records

  let(:marker) { described_class::MARKER }
  let(:trusted) { %w[example-owner example-member] }

  def ledger(body, sub_issues: [])
    described_class.new(comment("#{marker}\n#{body}"), sub_issues: sub_issues, home: home)
  end

  def items(body, sub_issues: [])
    ledger(body, sub_issues: sub_issues).items.map { |item| [item.id, item.kind, item.checked] }
  end

  describe '.locate' do
    def locate(comments)
      described_class.locate(comments) { |candidate| trusted.include?(candidate.author.login) }
    end

    it 'takes the earliest marker comment by a trusted author, ignoring and listing earlier ones by anyone else' do
      stranger = comment("#{marker}\n- [ ] **L1 Planted.**", author: author('example-stranger'), database_id: 1)
      ledger = comment("#{marker}\n- [ ] **L1 Real.**", author: author('example-owner'), database_id: 2)
      later = comment("#{marker}\n- [ ] **L1 Later.**", author: author('example-member'), database_id: 3)

      expect(locate([stranger, ledger, later])).to eq([ledger, [stranger]])
    end

    it 'counts a comment only when its body begins with the marker' do
      quoted = comment("See the breakdown:\n#{marker}", author: author('example-owner'), database_id: 1)
      indented = comment(" #{marker}", author: author('example-owner'), database_id: 2)

      expect(locate([quoted, indented])).to eq([nil, []])
    end
  end

  describe 'items' do
    it 'reads unindented boxes in order: L ids from a leading **L<n>, positions for the rest' do
      body = <<~MARKDOWN
        ## Breakdown
        - [x] **L1 Foundation.** Done.
        - [ ] **L2 `/do` pre-flight.**
          - [ ] a nested box is detail, not an item
        * [X] **L10 Ten.**
        - [ ] Plain work with no id
        - [ ] **L2a** is no L id
      MARKDOWN

      expect(items(body)).to eq([['L1', :item, true], ['L2', :item, false], ['L10', :item, true],
                                 ['P4', :item, false], ['P5', :item, false]])
    end

    it 'reads the boxes GitHub renders at the top level, whatever their marker or indentation' do
      expect(items("1. [ ] **L1 One.**\n   - [ ] detail\n - [x] **L2 Two.**\n").map(&:first)).to eq(%w[L1 L2])
    end

    it 'ignores checklists, gate lines and the adopted heading inside HTML comments' do
      hidden = ledger("<!--\n- [ ] **L1 Hidden.**\nGate G1: open\n### Adopted acceptance criteria\n-->\n" \
                      "- [ ] **L2 Real.**\n")

      expect([hidden.items.map(&:id), hidden.gates, hidden.adopted_criteria?]).to eq([['L2'], [], false])
    end

    it 'reads a gate line in HTML that GitHub shows as text, but not a box there' do
      shown = ledger("- [ ] **L1 One.**\n\n<details>\nGate G1: open\n- [ ] **L2 Raw.**\n</details>\n")

      expect(shown.gates.map(&:id)).to eq(['G1'])
      expect { shown.items }.to raise_error(Do::AmbiguousCheckbox) { |error| expect(error.lines).to eq([6]) }
    end

    it 'raises on its items when a line reads like a box it cannot place, which pre-flight reads as placed' do
      ambiguous = ledger("- [ ] **L1 One.**\n[ ] **L2 No marker.**\n\nGate G1: open\n")

      expect { ambiguous.items }.to raise_error(Do::AmbiguousCheckbox) { |error| expect(error.lines).to eq([3]) }
      expect([ambiguous.ambiguous, ambiguous.placed_items.map(&:id), ambiguous.first_unbuilt.id,
              ambiguous.gates.map(&:id)]).to eq([[3], ['L1'], 'L1', ['G1']])
    end

    it 'takes only its top-level boxes as items, a nested or quoted one being detail' do
      expect(items("- [ ] **L1 One.**\n  - [ ] **L2 detail**\n> - [ ] **L3 quoted**\n\n- [ ] **L4 Four.**\n"))
        .to eq([['L1', :item, false], ['L4', :item, false]])
    end

    it 'ignores checklists inside code fences' do
      body = "- [ ] **L1 Real.**\n```markdown\n- [ ] **L2 Quoted.**\n```\n" \
             "~~~\n- [ ] #5 quoted\n~~~\n- [ ] **L3 Real.**\n"

      expect(items(body).map(&:first)).to eq(%w[L1 L3])
    end

    describe 'sub-issue boxes' do
      let(:local_five) { issue_record(number: 5) }
      let(:other_five) { issue_record(number: 5, repository: repository('example-owner/other-repo')) }

      it "tells a local #5 from another repository's #5, matching the repository ignoring case" do
        body = "- [ ] #5 Here\n- [x] EXAMPLE-OWNER/Other-Repo#5 There\n- [ ] example-owner/example-repo#5 Here again\n"
        found = ledger(body, sub_issues: [local_five, other_five]).items

        expect(found.map { |item| [item.id, item.kind, item.sub_issue] })
          .to eq([['#5', :sub_issue, local_five], ['example-owner/other-repo#5', :sub_issue_elsewhere, other_five],
                  ['#5', :sub_issue, local_five]])
      end

      it "reads a bare #5 box as a plain item when only another repository's #5 is linked" do
        expect(items('- [ ] #5 Looks like a sub-issue', sub_issues: [other_five])).to eq([['P1', :item, false]])
      end

      it 'reads a box naming an issue GraphQL does not list as a sub-issue as a plain item' do
        expect(items("- [ ] #6 Not linked\n- [ ] example-owner/other-repo#6 Nor this"))
          .to eq([['P1', :item, false], ['P2', :item, false]])
      end

      it 'gives a sub-issue in a repository that may not be named its position, not its name' do
        hidden = issue_record(number: 7, repository: repository('example-owner/hidden', visibility: 'PRIVATE'))

        expect(items('- [ ] example-owner/hidden#7 Private work', sub_issues: [hidden]))
          .to eq([['P1', :sub_issue_elsewhere, false]])
      end

      it 'lets a leading **L<n> win over a sub-issue reference later in the box' do
        expect(items('- [ ] **L4** #5', sub_issues: [local_five])).to eq([['L4', :item, false]])
      end
    end
  end

  describe 'line numbers' do
    it "gives each item its index among the body's lines, counting fenced lines too" do
      body = "Intro\n```\n- [ ] **L9 Quoted.**\n```\n- [ ] **L1 One.**\r\n  - [ ] detail\n- [x] **L2 Two.**"

      expect(ledger(body).items.map { |item| [item.id, item.position, item.line, item.mark] })
        .to eq([['L1', 1, 5, 3], ['L2', 2, 7, 3]])
    end
  end

  describe '#resolve' do
    it 'finds the item each id names, and lists ids that name none or several' do
      found, missing = ledger("- [ ] **L1 One.**\n- [ ] **L2 Two.**\n- [x] **L2 Again.**\n- [ ] Plain\n")
                       .resolve(%w[L1 P4 L2 L3])

      expect([found.map(&:id), missing]).to eq([%w[L1 P4], %w[L2 L3]])
    end
  end

  describe '#first_unbuilt' do
    let(:elsewhere) { issue_record(number: 9, repository: repository('example-owner/other-repo')) }

    it 'is the first unticked item this run builds, skipping a sub-issue in another repository' do
      body = "- [x] **L1 Done.**\n- [ ] example-owner/other-repo#9 Tracked only\n" \
             "- [ ] **L2 Next.**\n- [ ] **L3 After.**\n"

      expect(ledger(body, sub_issues: [elsewhere]).first_unbuilt.id).to eq('L2')
    end

    it 'includes a sub-issue in this repository' do
      expect(ledger("- [x] **L1 Done.**\n- [ ] #5 Build me\n", sub_issues: [issue_record(number: 5)]).first_unbuilt.id)
        .to eq('#5')
    end

    it 'is nil when everything this run builds is ticked' do
      expect(ledger("- [x] **L1 Done.**\n- [ ] example-owner/other-repo#9\n", sub_issues: [elsewhere]).first_unbuilt)
        .to be_nil
    end
  end

  describe 'gate lines' do
    it 'reads plain "Gate G<k>: <state>" lines outside code fences, with their line numbers' do
      body = "Gate G1: open\nGate G2: fixed\nGate G3: user decided\n- [ ] Gate G4: open\n```\nGate G5: open\n```\n"

      expect(ledger(body).gates.map(&:to_h)).to eq([{ id: 'G1', state: 'open', line: 1 },
                                                    { id: 'G2', state: 'fixed', line: 2 },
                                                    { id: 'G3', state: 'user decided', line: 3 }])
    end

    it 'reads any state it does not recognise as open' do
      expect(ledger("Gate G1: Fixed\nGate G2: closed\nGate G3:\n").gates.map(&:state)).to eq(%w[open open open])
    end
  end

  describe 'adopted acceptance criteria' do
    it 'are recorded under the fixed heading, outside code fences' do
      expect([ledger("### Adopted acceptance criteria  \n- the criteria\n").adopted_criteria?,
              ledger("```\n### Adopted acceptance criteria\n```\n").adopted_criteria?,
              ledger("## Adopted acceptance criteria\n").adopted_criteria?]).to eq([true, false, false])
    end
  end
end
