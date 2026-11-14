# frozen_string_literal: true

require_relative '../lib/do/gate_file'
require_relative '../lib/do/ledger'

RSpec.describe Do::GateFile do
  let(:node_id) { 'I_kwDOExample' }
  let(:common_directory) { File.join(sandbox.work_directory, '.git') }
  let(:directory) { File.join(common_directory, 'do') }
  let(:path) { described_class.path(common_directory, node_id) }

  def gate_file(text)
    described_class.new(text)
  end

  def ledger_gates(*lines)
    lines.map { |line| Do::Ledger::Gate.new(id: line[0], state: line[1]) }
  end

  def write_gate_file(text)
    FileUtils.mkdir_p(directory)
    File.write(path, text)
  end

  describe '.path' do
    it "is <git common dir>/do/<issue node id>-gate.md, the directory's real path" do
      expect(path).to eq(File.join(File.realpath(common_directory), 'do', "#{node_id}-gate.md"))
    end

    it 'refuses a node id that could leave that directory' do
      ['../../config', '..', 'I_kw/../../x', "I_kw\n", '-I_kw', ''].each do |unsafe|
        expect { described_class.path(common_directory, unsafe) }
          .to raise_error(SkillSupport::InvalidIdentifier, 'invalid node_id'), unsafe.inspect
      end
    end
  end

  describe '.read' do
    it 'reads the findings in the file' do
      write_gate_file("## G1: open\nAnswer: fix here\n\nA finding.\n")

      expect(described_class.read(path).findings.map(&:to_h)).to eq([{ id: 'G1', state: 'open', answer: 'fix here' }])
    end

    it 'is empty when the file, or its directory, is missing' do
      expect(described_class.read(path).findings).to be_empty
      FileUtils.mkdir_p(directory)
      expect(described_class.read(path).findings).to be_empty
    end

    it 'refuses to follow a symlink as the file' do
      target = sandbox.path('elsewhere.md')
      File.write(target, "## G1: fixed\n")
      FileUtils.mkdir_p(directory)
      File.symlink(target, path)

      expect { described_class.read(path) }.to raise_error(Do::UnsafeGateFile, /is a symlink/)
    end

    it 'refuses to follow a symlink as its directory' do
      FileUtils.mkdir_p(sandbox.path('decoy'))
      File.write(File.join(sandbox.path('decoy'), File.basename(path)), "## G1: fixed\n")
      File.symlink(sandbox.path('decoy'), directory)

      expect { described_class.read(path) }.to raise_error(Do::UnsafeGateFile, /is a symlink/)
    end

    it 'refuses anything but a regular file, without waiting on a FIFO' do
      FileUtils.mkdir_p(directory)
      File.mkfifo(path)

      expect { described_class.read(path) }.to raise_error(Do::UnsafeGateFile, /not a regular file/)
    end
  end

  describe 'findings' do
    it 'reads each heading, with an Answer line when it is the first line after the heading' do
      text = <<~MARKDOWN
        ## G1: open

        Answer: advisory

        Text.

        ## G2: fixed
        Text first.
        Answer: advisory

        ## G3: user decided
      MARKDOWN

      expect(gate_file(text).findings.map(&:to_h)).to eq([{ id: 'G1', state: 'open', answer: 'advisory' },
                                                          { id: 'G2', state: 'fixed', answer: nil },
                                                          { id: 'G3', state: 'user decided', answer: nil }])
    end

    it 'takes headings and answers quoted in a code fence for finding text' do
      text = "## G1: open\nAnswer: fix here\n```\n## G1: fixed\n## G2: open\nAnswer: advisory\n```\n"

      expect(gate_file(text).findings.map(&:to_h)).to eq([{ id: 'G1', state: 'open', answer: 'fix here' }])
    end

    it 'reads a repeated heading as one finding, open if any says so and advisory if any answer does' do
      text = "## G1: fixed\nAnswer: advisory\n## G1: open\nAnswer: fix here\n## G1: user decided\n"

      expect(gate_file(text).findings.map(&:to_h)).to eq([{ id: 'G1', state: 'open', answer: 'advisory' }])
    end

    it 'reads a state it does not recognise as open' do
      expect(gate_file("## G1: Fixed\n## G2: done\n").findings.map(&:state)).to eq(%w[open open])
    end
  end

  describe '#status' do
    it 'counts a finding open while the file or the ledger says so' do
      status = gate_file("## G1: open\n## G2: fixed\n## G3: fixed\n")
               .status(ledger_gates(%w[G1 open], %w[G2 open], %w[G3 fixed]))

      expect(status.open).to eq(%w[G1 G2])
    end

    it 'lists an open finding answered advisory' do
      status = gate_file("## G2: open\nAnswer: advisory\n## G1: open\nAnswer: fix here\n")
               .status(ledger_gates(%w[G1 open]))

      expect(status.to_h).to include(open: %w[G1 G2], advisory: ['G2'])
    end

    it 'lists an open ledger line the file lacks, and every one when there is no file' do
      expect(gate_file("## G1: open\n").status(ledger_gates(%w[G1 open], %w[G2 open], %w[G3 fixed])).missing)
        .to eq(['G2'])
      expect(gate_file('').status(ledger_gates(%w[G1 open], %w[G10 open], %w[G2 open])).missing)
        .to eq(%w[G1 G2 G10])
    end

    it 'lists an open finding the ledger has no line for as left part-way' do
      status = gate_file("## G1: open\n## G2: open\n## G3: fixed\n").status(ledger_gates(%w[G1 open]))

      expect(status.partial).to eq(['G2'])
    end
  end
end
