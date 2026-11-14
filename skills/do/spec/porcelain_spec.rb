# frozen_string_literal: true

require_relative '../lib/do/porcelain'

RSpec.describe Do::Porcelain do
  it 'reads each entry of `git status --porcelain=v1 -z`, a rename with its original path' do
    entries = described_class.entries(" M README.md\0?? notes/a b.md\0R  new.md\0old.md\0A  added.md\0")

    expect(entries.map(&:to_h))
      .to eq([{ status: ' M', path: 'README.md', original: nil }, { status: '??', path: 'notes/a b.md', original: nil },
              { status: 'R ', path: 'new.md', original: 'old.md' }, { status: 'A ', path: 'added.md', original: nil }])
    expect(entries.map(&:to_s)).to eq([' M README.md', '?? notes/a b.md', 'R  old.md -> new.md', 'A  added.md'])
    expect(entries.map(&:untracked?)).to eq([false, true, false, false])
  end

  it 'reads a copy with its original path too, and nothing from nothing' do
    expect(described_class.entries("C  copy.md\0source.md\0").map(&:original)).to eq(['source.md'])
    expect(described_class.entries('')).to eq([])
  end

  it 'keeps a path with a newline in it whole' do
    expect(described_class.entries("?? odd\nname.md\0").map(&:path)).to eq(["odd\nname.md"])
  end
end
