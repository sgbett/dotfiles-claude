# frozen_string_literal: true

require_relative '../lib/do/finding_file'

RSpec.describe Do::FindingFile do
  let(:path) { sandbox.path('finding.md') }

  it 'reads a regular file' do
    File.write(path, "A flaw.\n")

    expect(described_class.read(path)).to eq("A flaw.\n")
  end

  it 'refuses a file that is missing, empty, a symlink or not a regular file' do
    File.write(sandbox.path('blank.md'), " \n")
    File.symlink(sandbox.path('blank.md'), sandbox.path('link.md'))
    File.mkfifo(sandbox.path('fifo'))

    { path => /doesn't exist/, sandbox.path('blank.md') => /is empty/, sandbox.path('link.md') => /is a symlink/,
      sandbox.path('fifo') => /not a regular file/, sandbox.root => /not a regular file/ }.each do |file, message|
      expect { described_class.read(file) }.to raise_error(Do::UnusableFindingFile, message), file
    end
  end
end
