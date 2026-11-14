# frozen_string_literal: true

require_relative '../lib/do/written_file'

RSpec.describe Do::WrittenFile do
  let(:path) { sandbox.path('argument.txt') }

  describe '.path!' do
    it "takes the path a flag was given, refusing one that's empty, reads as an option or holds a control character" do
      expect(described_class.path!(:argument_file, '/scratch/argument.txt')).to eq('/scratch/argument.txt')
      ['', '-x', "a\nb", nil].each do |value|
        expect { described_class.path!(:argument_file, value) }
          .to raise_error(SkillSupport::InvalidIdentifier, 'invalid argument_file'), value.inspect
      end
    end
  end

  describe '.read' do
    it 'reads a regular file as UTF-8, replacing any byte that is not' do
      File.binwrite(path, "24\xFF\n".b)

      expect(described_class.read(path)).to eq("24\u{FFFD}\n")
    end

    it 'refuses a file that is missing, a symlink or not a regular file, raising the error it is given' do
      File.write(sandbox.path('real.txt'), "24\n")
      File.symlink(sandbox.path('real.txt'), sandbox.path('link.txt'))
      File.mkfifo(sandbox.path('fifo'))
      error = Class.new(Do::UnusableFile)

      { path => /doesn't exist/, sandbox.path('link.txt') => /is a symlink/,
        sandbox.path('fifo') => /not a regular file/, sandbox.root => /not a regular file/ }.each do |file, message|
        expect { described_class.read(file, error: error) }.to raise_error(error, message), file
      end
    end
  end
end
