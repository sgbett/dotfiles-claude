# frozen_string_literal: true

require_relative '../lib/do/private_file'

RSpec.describe Do::PrivateFile do
  let(:directory) { sandbox.path('private') }
  let(:path) { File.join(directory, 'record.md') }

  it 'makes a missing directory 0700 and the file 0600' do
    described_class.write(path, "text\n")

    expect([File.stat(directory).mode & 0o777, File.stat(path).mode & 0o777, File.read(path)])
      .to eq([0o700, 0o600, "text\n"])
  end

  it 'tightens a directory that was looser, and replaces a file that was' do
    FileUtils.mkdir_p(directory, mode: 0o755)
    File.write(path, 'old')
    File.chmod(0o644, path)
    described_class.write(path, 'new')

    expect([File.stat(directory).mode & 0o777, File.stat(path).mode & 0o777, File.read(path)])
      .to eq([0o700, 0o600, 'new'])
    expect(Dir.children(directory)).to eq(['record.md'])
  end

  it 'refuses a directory reached through a symlink, writing nothing there' do
    decoy = sandbox.path('decoy')
    FileUtils.mkdir_p(decoy)
    File.symlink(decoy, directory)

    expect { described_class.write(path, 'text') }.to raise_error(Do::UnsafeGateFile, /is a symlink/)
    expect(Dir.children(decoy)).to be_empty
  end

  it 'replaces a symlink at the path rather than writing through it' do
    target = sandbox.path('target.md')
    File.write(target, 'untouched')
    FileUtils.mkdir_p(directory)
    File.symlink(target, path)
    described_class.write(path, 'text')

    expect([File.symlink?(path), File.read(path), File.read(target)]).to eq([false, 'text', 'untouched'])
  end

  it 'leaves the old file as it was, and nothing beside it, when the write fails' do
    FileUtils.mkdir_p(directory)
    File.write(path, 'old')
    allow(File).to receive(:rename).and_raise(Errno::EXDEV)

    expect { described_class.write(path, 'new') }.to raise_error(Errno::EXDEV)
    expect([File.read(path), Dir.children(directory)]).to eq(['old', ['record.md']])
  end
end
