# frozen_string_literal: true

require_relative '../lib/copilot_check/output_file'

RSpec.describe CopilotCheck::OutputFile do
  let(:directory) { sandbox.path('scratch') }

  before { FileUtils.mkdir_p(directory) }

  it 'writes the file for its owner alone, replacing one already there, and leaves nothing beside it' do
    path = File.join(directory, 'rubric.md')
    File.write(path, 'old')

    described_class.write(path, "## Do not flag\n")

    expect([File.read(path), File.stat(path).mode & 0o777]).to eq(["## Do not flag\n", 0o600])
    expect(Dir.children(directory)).to eq(['rubric.md'])
  end

  it 'replaces a symlink at the path rather than writing through it' do
    target = sandbox.path('elsewhere.txt')
    File.write(target, 'untouched')
    path = File.join(directory, 'pr0.json')
    File.symlink(target, path)

    described_class.write(path, '{}')

    expect([File.symlink?(path), File.read(path), File.read(target)]).to eq([false, '{}', 'untouched'])
  end

  it "fails where the directory doesn't exist or the path is a directory, leaving nothing behind" do
    expect { described_class.write(sandbox.path('missing', 'pr0.json'), '{}') }
      .to raise_error(CopilotCheck::UnwritableFile, /missing doesn't exist/)
    FileUtils.mkdir_p(File.join(directory, 'pr0.json'))
    expect { described_class.write(File.join(directory, 'pr0.json'), '{}') }
      .to raise_error(CopilotCheck::UnwritableFile, /pr0.json is a directory/)
    expect(Dir.children(directory)).to eq(['pr0.json'])
  end

  describe '.directory' do
    it 'makes a missing directory for its owner alone, and takes one that exists' do
      made = described_class.directory(File.join(directory, 'round-1'))

      expect(File.stat(made).mode & 0o777).to eq(0o700)
      expect(described_class.directory(made)).to eq(made)
    end

    it "refuses a symlink, a file, and a directory whose parent doesn't exist" do
      File.symlink(sandbox.path, File.join(directory, 'linked'))
      File.write(File.join(directory, 'file'), '')

      { 'linked' => /is a symlink/, 'file' => /is not a directory/, 'missing/round-1' => /missing doesn't exist/ }
        .each do |name, message|
          expect { described_class.directory(File.join(directory, name)) }
            .to raise_error(CopilotCheck::UnwritableFile, message), name
        end
    end
  end
end
