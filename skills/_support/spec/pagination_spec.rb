# frozen_string_literal: true

RSpec.describe SkillSupport::Pagination do
  def labels(page_info)
    { 'repository' => { 'labels' => { 'pageInfo' => page_info, 'nodes' => [] } } }
  end

  it 'returns a connection whose pageInfo shows no other page' do
    data = labels('hasNextPage' => false, 'hasPreviousPage' => false)

    expect(described_class.ensure_complete!(data, 'repository', 'labels')).to eq(data.dig('repository', 'labels'))
  end

  it 'raises when a connection overflows its page, as recorded from GitHub' do
    data = JSON.parse(fixture('graphql/labels-first-page.json')).fetch('data')

    expect { described_class.ensure_complete!(data, 'repository', 'labels') }
      .to raise_error(SkillSupport::IncompleteResults, 'repository.labels has more than one page')
  end

  it 'raises when a last: query has earlier entries' do
    expect { described_class.ensure_complete!(labels('hasPreviousPage' => true), 'repository', 'labels') }
      .to raise_error(SkillSupport::IncompleteResults, 'repository.labels has more than one page')
  end

  it 'fails closed when the connection, its pageInfo or both page flags are missing' do
    [{}, { 'repository' => nil }, { 'repository' => { 'labels' => { 'nodes' => [] } } },
     labels({}), labels('endCursor' => 'Y3Vyc29y'), labels(nil)].each do |data|
      expect { described_class.ensure_complete!(data, 'repository', 'labels') }
        .to raise_error(SkillSupport::IncompleteResults, /no pageInfo/), "accepted #{data.inspect}"
    end
  end

  it 'fails closed on a page flag that is not false' do
    [nil, 'false', 0].each do |flag|
      expect { described_class.ensure_complete!(labels('hasNextPage' => flag), 'repository', 'labels') }
        .to raise_error(SkillSupport::IncompleteResults), "accepted hasNextPage #{flag.inspect}"
    end
  end
end
