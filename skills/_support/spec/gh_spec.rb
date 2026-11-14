# frozen_string_literal: true

RSpec.describe SkillSupport::Gh do
  subject(:gh) { described_class.new(host: 'github.com', runner: fake_runner) }

  let(:profiles_call) do
    %w[api --hostname github.com -X GET repos/sgbett/dotfiles-claude/contents/profiles -f ref=master]
  end

  it 'refuses a host that is not a bare host name' do
    expect { described_class.new(host: 'https://github.com', runner: fake_runner) }
      .to raise_error(SkillSupport::InvalidIdentifier, 'invalid host')
  end

  describe '#json' do
    it 'runs gh with the arguments given and parses what it prints' do
      fake_runner.expect_call(['gh', *profiles_call], stdout: fixture('contents/profiles.json'))

      expect(gh.json(profiles_call).map { |entry| entry['name'] }).to eq(%w[git-workflow.md work-organisation.md])
    end

    it 'raises GhError with the exit status, stderr and HTTP answer when gh fails' do
      fake_runner.expect_call(['gh', *profiles_call], exit_status: 1,
                                                      stdout: fixture('contents/bad-credentials.json'),
                                                      stderr: fixture('contents/bad-credentials.stderr'))

      expect { gh.json(profiles_call) }.to raise_error(SkillSupport::GhError, /Bad credentials \(HTTP 401\)/) { |error|
        expect([error.exit_status, error.http_status, error.api_message]).to eq([1, 401, 'Bad credentials'])
      }
    end

    it 'raises UnexpectedResponse when gh succeeds but prints something other than JSON' do
      fake_runner.expect_call(['gh', *profiles_call], stdout: 'not json')

      expect { gh.json(profiles_call) }.to raise_error(SkillSupport::UnexpectedResponse)
    end
  end

  describe '#api' do
    it 'sends a GET with each field as one -f argument, naming the host' do
      fake_runner.expect_call(['gh', 'api', '--hostname', 'github.com', '-X', 'GET',
                               'repos/twbs/bootstrap/contents/README.md', '-f', 'ref=feat/#24+x'], stdout: '{}')

      expect(gh.api('repos/twbs/bootstrap/contents/README.md', fields: { 'ref' => 'feat/#24+x' })).to eq({})
    end

    it 'sends another method its body as JSON on stdin through --input -' do
      path = 'repos/example-owner/example-repo/issues/comments/7'
      body = { 'body' => "- [x] **L1 Foundation.**\n" }
      fake_runner.expect_call(['gh', 'api', '--hostname', 'github.com', '-X', 'PATCH', path, '--input', '-'],
                              stdin: JSON.generate(body), stdout: '{"id":7}')

      expect(gh.api(path, method: 'PATCH', body: body)).to eq('id' => 7)
    end

    it 'refuses a path that could become an option, a query, a fragment or a traversal' do
      ['', '-X', '--input=x', '/repos/o/r', 'repos//r', 'repos/o/r?ref=x', 'repos/o/r#x', 'repos/o/../r', 'repos/o/r ',
       nil].each do |path|
        expect { gh.api(path) }.to raise_error(ArgumentError), "accepted #{path.inspect}"
      end
    end

    it 'sends GraphQL only through #graphql, which checks its errors' do
      expect { gh.api('graphql', method: 'POST', body: { 'query' => '{ viewer { login } }' }) }
        .to raise_error(ArgumentError, /#graphql/)
    end

    it 'refuses a body on a GET, fields on any other method, an unknown method and malformed fields' do
      expect { gh.api('user', body: {}) }.to raise_error(ArgumentError)
      expect { gh.api('repos/o/r/issues/1', method: 'PATCH', fields: { 'state' => 'closed' }) }
        .to raise_error(ArgumentError)
      expect { gh.api('user', method: 'TRACE') }.to raise_error(ArgumentError)
      expect { gh.api('user', fields: { 'a=b' => 'c' }) }.to raise_error(ArgumentError)
      expect { gh.api('user', fields: { 'ref' => 1 }) }.to raise_error(ArgumentError)
    end
  end

  describe '#graphql' do
    let(:arguments) { %w[gh api graphql --hostname github.com --input -] }

    def recorded_request(name)
      JSON.parse(fixture("graphql/#{name}.request.json"))
    end

    it 'sends the query with its variables beside it as JSON on stdin, and returns the data' do
      request = recorded_request('labels-first-page')
      fake_runner.expect_call(arguments, stdin: JSON.generate(request),
                                         stdout: fixture('graphql/labels-first-page.json'))

      data = gh.graphql(request['query'], request['variables'])

      expect(data.dig('repository', 'nameWithOwner')).to eq('twbs/bootstrap')
    end

    it 'raises GraphqlError for errors that came back with partial data, as recorded from GitHub' do
      request = recorded_request('partial-data-with-errors')
      fake_runner.expect_call(arguments, stdin: JSON.generate(request), exit_status: 1,
                                         stdout: fixture('graphql/partial-data-with-errors.json'),
                                         stderr: fixture('graphql/partial-data-with-errors.stderr'))

      expect { gh.graphql(request['query'], request['variables']) }
        .to raise_error(SkillSupport::GraphqlError, /Could not resolve to a User/) { |error|
          expect(error.errors.map { |entry| entry['type'] }).to eq(['NOT_FOUND'])
        }
    end

    it 'raises GraphqlError for errors with data even when gh exits 0' do
      response = '{"data":{"repository":null},"errors":[{"type":"FORBIDDEN","message":"Resource not accessible"}]}'
      fake_runner.expect_call(arguments, stdin: JSON.generate('query' => '{ x }', 'variables' => {}), stdout: response)

      expect { gh.graphql('{ x }') }
        .to raise_error(SkillSupport::GraphqlError, 'GraphQL errors: Resource not accessible')
    end

    it 'raises GhError when gh fails without a GraphQL answer' do
      fake_runner.expect_call(arguments, stdin: JSON.generate('query' => '{ x }', 'variables' => {}), exit_status: 1,
                                         stdout: fixture('contents/bad-credentials.json'),
                                         stderr: fixture('contents/bad-credentials.stderr'))

      expect { gh.graphql('{ x }') }.to raise_error(SkillSupport::GhError) { |error|
        expect(error).not_to be_a(SkillSupport::GraphqlError)
        expect(error.http_status).to eq(401)
      }
    end

    it 'raises UnexpectedResponse when no data came back' do
      fake_runner.expect_call(arguments, stdin: JSON.generate('query' => '{ x }', 'variables' => {}), stdout: '{}')

      expect { gh.graphql('{ x }') }.to raise_error(SkillSupport::UnexpectedResponse)
    end
  end

  describe '#repo_view' do
    it 'views a repository by a URL, which names its host' do
      url = 'https://github.com/bettison-org/ai-software-architect'
      fake_runner.expect_call(['gh', 'repo', 'view', url, '--json', 'nameWithOwner,parent'],
                              stdout: fixture('repo-view/fork.json'))

      expect(gh.repo_view(url, %w[nameWithOwner parent]).dig('parent', 'owner', 'login')).to eq('codenamev')
    end

    it 'accepts every URL form gh reads as a URL' do
      urls = %w[https://github.com/o/r http://ghe.example.com/o/r ssh://git@github.com/o/r.git git://github.com/o/r
                git+ssh://git@github.com/o/r git+https://github.com/o/r git@github.com:o/r.git]
      urls.each do |url|
        fake_runner.expect_call(['gh', 'repo', 'view', url, '--json', 'url'], stdout: '{}')

        expect(gh.repo_view(url, ['url'])).to eq({})
      end
    end

    it 'refuses OWNER/REPO, local paths, options and empty values, which gh would resolve against github.com' do
      ['', 'sgbett/dotfiles-claude', '../dotfiles-claude', '/srv/git/repo.git', 'file:///srv/git/repo', '-R',
       '--json=x', "https://github.com/o/r\n", 'https://github.com/o/r extra', nil].each do |url|
        expect { gh.repo_view(url, ['url']) }.to raise_error(SkillSupport::InvalidIdentifier), "accepted #{url.inspect}"
      end
    end

    it 'needs at least one well-formed JSON field' do
      expect { gh.repo_view('https://github.com/o/r', []) }.to raise_error(ArgumentError)
      expect { gh.repo_view('https://github.com/o/r', ['name,owner']) }.to raise_error(ArgumentError)
    end
  end

  describe '#logged_in?' do
    it "asks gh auth status about the host's active account alone, true only when it exits 0" do
      expect_gh_login('ghe.example.com')
      expect_gh_login('ghe.example.com', logged_in: false)
      ghe = described_class.new(host: 'ghe.example.com', runner: fake_runner)

      expect([ghe.logged_in?, ghe.logged_in?]).to eq([true, false])
    end
  end
end
