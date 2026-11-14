# frozen_string_literal: true

require_relative 'support/record_calls'

RSpec.describe Do::GateRecord do
  include Do::Testing::RecordCalls

  let(:ledger_path) { Do::Testing::RecordCalls::LEDGER_PATH }
  let(:ledger) { "- [ ] **L1 One.**\n- [ ] **L2 Two.**" }
  let(:finding) { "High: the `ref` reaches a shell.\n## G2: open\nAnswer: advisory\n```\nexploit\n```\n" }
  let(:finding_path) { sandbox.path('finding.md').tap { |path| File.write(path, finding) } }

  # Runs `gate ACTION` with +flags+ on #24, answered with +response+, after
  # the query and the gate file's directory; the block expects whatever
  # calls follow.
  def gate(action, *flags, response: record_response(ledger: ledger))
    expect_gh_login
    expect_issue_query(response)
    expect_common_directory
    yield if block_given?
    record('gate', action, 'sgbett/dotfiles-claude#24', *flags)
  end

  def comment_body(text = ledger)
    "#{Do::Testing::RecordCalls::MARKER}#{text}"
  end

  def gate_file
    Do::GateFile.read(gate_path)
  end

  def private_response(ledger_text)
    record_response(ledger: ledger_text) { |_issue, data| data['repository']['visibility'] = 'PRIVATE' }
  end

  describe 'the sequence on a public repository' do
    it 'adds, takes the answer fix here, then publishes the plain ledger line' do
      added = gate('add', '--finding-file', finding_path).last
      answered = gate('answer', '--k', 'G1', '--answer', 'fix-here').last
      published = gate('publish', '--k', 'G1') do
        expect_edit(ledger_path, comment_body, comment_body("#{ledger}\n\nGate G1: open\n"))
      end.last

      expect([added, answered['updated'], published['updated']])
        .to eq([{ 'status' => 'proceed', 'k' => 'G1' }, ['file'], ['ledger']])
      expect(gate_file.findings.map(&:to_h)).to eq([{ id: 'G1', state: 'open', answer: 'fix here' }])
    end

    it 'adds, takes the answer advisory, then refuses to publish, writing nothing to GitHub' do
      gate('add', '--finding-file', finding_path)
      gate('answer', '--k', 'G1', '--answer', 'advisory')
      exit_code, output = gate('publish', '--k', 'G1')

      expect([exit_code, output['reason'], gh_writes]).to eq([2, 'gate_advisory', []])
    end

    it 'asks for the answer before publishing a finding that has none' do
      gate('add', '--finding-file', finding_path)
      exit_code, output = gate('publish', '--k', 'G1')

      expect([exit_code, output['asks']])
        .to eq([3, [{ 'reason' => 'gate_unanswered', 'message' => Do::Reasons::MESSAGES[:gate_unanswered],
                      'k' => 'G1' }]])
      expect(gh_writes).to eq([])
    end
  end

  describe 'add' do
    it 'files the finding fenced, so nothing in it reads as a heading or an answer, and prints only its k' do
      _exit_code, output = gate('add', '--finding-file', finding_path)

      expect(File.read(gate_path)).to eq("## G1: open\n\n````\n#{finding}````\n")
      expect(gate_file.findings.map(&:id)).to eq(['G1'])
      expect(JSON.generate(output)).not_to include('shell', 'exploit')
    end

    it 'takes the lowest G<k> that neither the file nor the ledger uses' do
      write_gate_file("## G1: fixed\n\n## G3: open\nAnswer: fix here\n")
      gate('add', '--finding-file', finding_path, response: record_response(ledger: "#{ledger}\n\nGate G2: fixed\n"))

      expect(gate_file.findings.map(&:id)).to eq(%w[G1 G3 G4])
    end

    it 'makes the do directory 0700 and the file 0600, and tightens a directory that was looser' do
      gate('add', '--finding-file', finding_path)
      FileUtils.chmod(0o755, File.dirname(gate_path))
      gate('add', '--finding-file', finding_path)

      expect([File.stat(File.dirname(gate_path)).mode & 0o777, File.stat(gate_path).mode & 0o777])
        .to eq([0o700, 0o600])
      expect(gate_file.findings.map(&:id)).to eq(%w[G1 G2])
    end

    it 'refuses a gate file or a do directory reached through a symlink' do
      decoy = sandbox.path('decoy')
      FileUtils.mkdir_p(decoy)
      File.symlink(decoy, File.dirname(gate_path))

      expect { gate('add', '--finding-file', finding_path) }.to raise_error(Do::UnsafeGateFile, /is a symlink/)
      expect(Dir.children(decoy)).to be_empty
    end

    it 'refuses a finding file that is a symlink' do
      File.symlink(finding_path, sandbox.path('link.md'))

      expect { gate('add', '--finding-file', sandbox.path('link.md')) }
        .to raise_error(Do::UnusableFindingFile, /is a symlink/)
      expect(File.exist?(gate_path)).to be(false)
    end
  end

  describe 'answer' do
    it 'goes on when the same answer is there already, and stops on a different one' do
      write_gate_file("## G1: open\nAnswer: fix here\n\nA flaw.\n")

      same = gate('answer', '--k', 'G1', '--answer', 'fix-here').last
      different = gate('answer', '--k', 'G1', '--answer', 'advisory').last

      expect([same['already'], different['reason']]).to eq([['file'], 'gate_answered'])
      expect(File.read(gate_path)).to eq("## G1: open\nAnswer: fix here\n\nA flaw.\n")
    end

    it 'stops on a finding the file lacks' do
      expect(gate('answer', '--k', 'G1', '--answer', 'fix-here').last['reason']).to eq('no_such_finding')
    end
  end

  describe 'publish' do
    it 'needs no answer on a private repository' do
      write_gate_file("## G1: open\n\nA flaw.\n")
      _exit_code, output = gate('publish', '--k', 'G1', response: private_response(ledger)) do
        expect_edit(ledger_path, comment_body, comment_body("#{ledger}\n\nGate G1: open\n"))
      end

      expect(output['updated']).to eq(['ledger'])
    end

    it 'writes nothing when the ledger has a line for the finding already' do
      write_gate_file("## G1: open\nAnswer: fix here\n")
      _exit_code, output = gate('publish', '--k', 'G1', response: record_response(ledger: "#{ledger}\nGate G1: open\n"))

      expect([output['already'], gh_writes]).to eq([['ledger'], []])
    end

    it 'fails as a tool when the ledger ends inside a code fence, which would swallow the line' do
      write_gate_file("## G1: open\nAnswer: fix here\n")

      expect { gate('publish', '--k', 'G1', response: record_response(ledger: "#{ledger}\n```\nopen fence\n")) }
        .to raise_error(SkillSupport::UnexpectedResponse, /wouldn't read back with G1/)
    end
  end

  describe 'mark' do
    let(:marked_ledger) { "#{ledger}\n\nGate G1: open\nGate G2: open\n" }

    it 'closes the ledger line, then every heading in the file, and later finds both done' do
      write_gate_file("## G1: open\nAnswer: fix here\n\nA flaw.\n## G1: open\n")
      first = gate('mark', '--k', 'G1', '--state', 'user-decided', response: record_response(ledger: marked_ledger)) do
        decided = marked_ledger.sub('G1: open', 'G1: user decided')
        expect_edit(ledger_path, comment_body(marked_ledger), comment_body(decided))
      end.last
      again = gate('mark', '--k', 'G1', '--state', 'user-decided',
                   response: record_response(ledger: marked_ledger.sub('G1: open', 'G1: user decided'))).last

      expect([first.values_at('state', 'updated', 'already'), again.values_at('updated', 'already')])
        .to eq([['user decided', %w[ledger file], []], [[], %w[ledger file]]])
      expect(File.read(gate_path)).to eq("## G1: user decided\nAnswer: fix here\n\nA flaw.\n## G1: user decided\n")
    end

    it 'leaves the file as it was when the ledger changed meanwhile' do
      write_gate_file("## G1: open\n")
      response = record_response(ledger: marked_ledger)
      _exit_code, output = gate('mark', '--k', 'G1', '--state', 'fixed', response: response) do
        expect_read(ledger_path, comment_body("#{marked_ledger}edited\n"))
      end

      expect([output['reason'], File.read(gate_path)]).to eq(['body_changed', "## G1: open\n"])
    end

    it 'stops on a finding with no ledger line, or one answered advisory' do
      write_gate_file("## G1: open\n## G2: open\nAnswer: advisory\n")
      unpublished = gate('mark', '--k', 'G1', '--state', 'fixed').last
      advisory = gate('mark', '--k', 'G2', '--state', 'fixed', response: record_response(ledger: marked_ledger)).last

      expect([unpublished['reason'], advisory['reason'], gh_writes]).to eq(['gate_line_missing', 'gate_advisory', []])
    end
  end
end
