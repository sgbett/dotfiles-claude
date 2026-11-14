# frozen_string_literal: true

RSpec.describe SkillSupport::Testing::GhShim do
  let(:not_found_args) do
    %w[api --hostname github.com -X GET repos/sgbett/dotfiles-claude/contents/no-such-file.md -f ref=master]
  end

  def gh(*arguments, stdin: '')
    Open3.capture3('gh', *arguments, stdin_data: stdin)
  end

  it 'serves the recorded stdout, stderr and exit status for an exact argument list' do
    install_gh_shim([{ args: not_found_args, stdout_file: fixture_path('contents/not-found.json'),
                       stderr: fixture('contents/not-found.stderr'), exit: 1 }])

    stdout, stderr, status = gh(*not_found_args)

    expect([stdout, stderr, status.exitstatus])
      .to eq([fixture('contents/not-found.json'), fixture('contents/not-found.stderr'), 1])
  end

  it 'fails loudly on a call it has no fixture for, a near miss included' do
    shim = install_gh_shim([{ args: not_found_args, stdout: '{}' }])

    [%w[api user], not_found_args[0..-2] + ['ref=main']].each do |arguments|
      stdout, stderr, status = gh(*arguments)

      expect([stdout, status.exitstatus]).to eq(['', 97])
      expect(stderr).to start_with("gh shim: no fixture for gh #{arguments.inspect}")
    end
    expect(shim.unmatched_calls.length).to eq(2)
  end

  it 'matches stdin when the fixture names it' do
    install_gh_shim([{ args: %w[api graphql --hostname github.com --input -], stdin: '{"query":"{ a }"}',
                       stdout: '{"data":{}}' }])

    expect(gh('api', 'graphql', '--hostname', 'github.com', '--input', '-', stdin: '{"query":"{ b }"}')[2].exitstatus)
      .to eq(97)
    expect(gh('api', 'graphql', '--hostname', 'github.com', '--input', '-', stdin: '{"query":"{ a }"}')[0])
      .to eq('{"data":{}}')
  end

  it 'answers with each entry once, in order, unless it repeats' do
    install_gh_shim([{ args: %w[api user], stdout: 'first' }, { args: %w[api user], stdout: 'second' },
                     { args: %w[api rate_limit], stdout: 'always', repeat: true }])

    expect(Array.new(3) { gh('api', 'user')[0] }).to eq(['first', 'second', ''])
    expect(Array.new(2) { gh('api', 'rate_limit')[0] }).to eq(%w[always always])
  end

  it 'logs every call it receives' do
    shim = install_gh_shim([{ args: %w[api user], stdout: '{}' }])
    gh('api', 'user')
    gh('api', 'user', stdin: 'piped')

    expect(shim.calls).to eq([{ 'args' => %w[api user], 'stdin' => '', 'fixture' => 0 },
                              { 'args' => %w[api user], 'stdin' => 'piped', 'fixture' => nil }])
  end

  it 'stands in for gh behind the library' do
    request = JSON.parse(fixture('graphql/labels-first-page.request.json'))
    shim = install_gh_shim([{ args: %w[api graphql --hostname github.com --input -], stdin: JSON.generate(request),
                              stdout_file: fixture_path('graphql/labels-first-page.json') }])

    data = SkillSupport::Gh.new(host: 'github.com').graphql(request['query'], request['variables'])

    expect(data.dig('repository', 'labels', 'nodes').map { |label| label['name'] }).to eq(%w[css docs])
    expect(shim.unmatched_calls).to be_empty
  end
end
