# frozen_string_literal: true

require_relative '../lib/do/facts'
require_relative 'support/issue_responses'

RSpec.describe Do::Facts do
  include Do::Testing::IssueResponses

  let(:branch) { 'feat/24-hlr-do-and-copilot-check-move' }
  let(:gate_path) { File.join(sandbox.work_directory, '.git', 'do', 'I_kwDOQzoXSs8AAAABfBUanQ-gate.md') }
  let(:title) { JSON.parse(fixture('graphql/issue-24.json')).dig('data', 'repository', 'issueOrPullRequest', 'title') }

  def run(reference = 'sgbett/dotfiles-claude#24')
    outcome = described_class.new(reference, runner: fake_runner).call
    [outcome.exit_code, JSON.parse(outcome.to_json)]
  end

  # The local calls that follow the query: the gate file's directory, then
  # the default branch.
  def expect_local_calls
    fake_runner.expect_call(%w[git rev-parse --path-format=absolute --git-common-dir],
                            stdout: "#{sandbox.work_directory}/.git\n")
    fake_runner.expect_call(['git', 'check-ref-format', '--branch', branch], stdout: "#{branch}\n")
  end

  # The issue body's read, which follows them when it holds the acceptance
  # criteria: by default #24's, as recorded.
  def expect_issue_body(body = nil, host: 'github.com', repository: recorded_repository)
    stdout = body ? JSON.generate('body' => body) : fixture('rest/issue-24.json')
    fake_runner.expect_call(['gh', 'api', '--hostname', host, '-X', 'GET', "repos/#{repository}/issues/24"],
                            stdout: stdout)
  end

  # +body+ is false when the criteria live in the ledger, so no body is read.
  def facts(response = issue_response, reference: 'sgbett/dotfiles-claude#24', body: nil)
    expect_gh_login
    expect_issue_query(response)
    expect_local_calls
    expect_issue_body(body) unless body == false
    run(reference)
  end

  def untrusted!(node)
    node.merge!('author' => { 'login' => 'example-stranger' }, 'authorAssociation' => 'NONE',
                'viewerDidAuthor' => false)
  end

  def write_gate_file(text)
    FileUtils.mkdir_p(File.dirname(gate_path))
    File.write(gate_path, text)
  end

  # Every string in +output+ with the keys that lead to it.
  def texts(value, path = [])
    case value
    when Hash then value.flat_map { |key, child| texts(child, path + [key]) }
    when Array then value.flat_map { |child| texts(child, path) }
    when String then [[path, value]]
    else []
    end
  end

  describe 'the recorded issue' do
    it 'proceeds with its facts, status first and the fields in the order the lead reads them' do
      exit_code, output = facts(fixture('graphql/issue-24.json'))

      expect([exit_code, output.keys])
        .to eq([0, %w[status reference summary repository issue parent sub_issues ledger ignored_markers gate
                      branches parent_branches slug default_branch read session_only]])
      expect(output['reference']).to eq('sgbett/dotfiles-claude#24')
      expect(output['summary']).to eq('issue' => 'sgbett/dotfiles-claude#24', 'untrusted_authors' => [],
                                      'parent' => nil, 'resume_point' => 'L1', 'open_gate_findings' => [],
                                      'ignored_markers' => [], 'skipped_sub_issues' => [])
      expect(output['issue']).to include('number' => 24, 'author' => 'sgbett', 'trusted' => true,
                                         'trust_reason' => 'viewer', 'github_text' => { 'title' => title })
      expect(output.values_at('slug', 'default_branch', 'read'))
        .to eq(['hlr-do-and-copilot-check-move', branch, ['references/resume.md']])
      expect(output['session_only']).to eq('gate_file' => gate_path, 'not_nameable' => [], 'unusable_branches' => [])
      expect(output['repository'].values_at('default_branch_ref', 'labels_truncated')).to eq(['master', false])
    end

    it 'finds the ledger with items L1 to L11 and no gate lines' do
      _exit_code, output = facts(fixture('graphql/issue-24.json'))

      expect(output['ledger']).to include('comment_id' => 6_867_069_660, 'author' => 'sgbett', 'gates' => [],
                                          'first_unbuilt' => 'L1', 'adopted_criteria' => false)
      expect(output['ledger']['items'].map { |item| item.values_at('id', 'kind', 'checked') })
        .to eq((1..11).map { |n| ["L#{n}", 'item', false] })
    end

    it 'prints no body, and GitHub text only under github_text' do
      _exit_code, output = facts(fixture('graphql/issue-24.json'))

      expect(JSON.generate(output)).not_to include('<!-- do:breakdown -->', 'Shared decisions')
      expect(texts(output).select { |_path, text| text == title }.map(&:first))
        .to eq([%w[issue github_text title]])
      expect(texts(output).reject { |path, _text| path.include?('github_text') }.map(&:last)).to all(be_ascii_only)
    end

    it 'reads the issue the same from a URL, giving owner/repo#N for every later call' do
      _exit_code, output = facts(reference: 'https://github.com/sgbett/dotfiles-claude/issues/24')

      expect(output.values_at('reference', 'summary'))
        .to match(['sgbett/dotfiles-claude#24', include('issue' => 'sgbett/dotfiles-claude#24')])
    end

    it 'gives the reference in the name GitHub gives the repository, whatever case the user wrote' do
      expect_gh_login
      expect_issue_query(issue_response, repository: 'SGBETT/Dotfiles-Claude')
      expect_local_calls
      expect_issue_body

      expect(run('SGBETT/Dotfiles-Claude#24').last['reference']).to eq('sgbett/dotfiles-claude#24')
    end

    it 'goes on with the first 100 labels when there are more, saying so, as labels decide nothing' do
      _exit_code, output = facts(issue_response do |_issue, data|
        data['repository']['labels']['pageInfo']['hasNextPage'] = true
      end)

      expect([output['status'], output['repository']['labels'].length, output['repository']['labels_truncated']])
        .to eq(['proceed', 10, true])
    end
  end

  describe "the issue body's boxes" do
    it 'lists each by position, ticked or not, with the start of its text as a label under github_text' do
      _exit_code, output = facts

      boxes = output['issue']['boxes']
      expect(boxes.map { |box| box.values_at('position', 'checked') }).to eq((1..11).map { |n| [n, false] })
      expect(boxes.first['github_text']['label'])
        .to eq('**Pre-flight is a tested script.** `skills/do/bin/preflight…')
      expect(boxes.map { |box| box['github_text']['label'].length }.max).to eq(60)
    end

    it 'counts them as GitHub renders them: any marker, nested ones and those in comments left out' do
      body = "Intro\n1. [ ] One\n   - [x] a detail\n2. [X] Two\n\n<!--\n- [ ] Not rendered\n-->\n * [ ] Three\n"
      _exit_code, output = facts(body: body)

      expect(output['issue']['boxes'].map { |box| [box['position'], box['checked'], box['github_text']['label']] })
        .to eq([[1, false, 'One'], [2, true, 'Two'], [3, false, 'Three']])
    end

    it 'lists none, reading no body, when the acceptance criteria live in the ledger' do
      response = issue_response do |issue|
        untrusted!(issue)
        issue['comments']['nodes'][0]['body'] += "\n### Adopted acceptance criteria\n- the confirmed criteria\n"
      end

      expect(facts(response, body: false).last['issue']['boxes']).to be_nil
    end

    it 'stops, naming the lines, when a line of the body or the ledger reads like a box it cannot place' do
      body_stop = facts(body: "- [ ] One\n[ ] Two, with no list marker\n").last
      ledger_stop = facts(issue_response do |issue|
        issue['comments']['nodes'][0]['body'] = "<!-- do:breakdown -->\n- [ ] **L1 One.**\n-  [ ]x **L2**\n"
      end).last

      expect([body_stop, ledger_stop].map { |output| output.values_at('status', 'reason', 'target', 'lines') })
        .to eq([['stop', 'ambiguous_checkbox', 'issue_body', [2]], ['stop', 'ambiguous_checkbox', 'ledger', [3]]])
    end
  end

  describe 'another host' do
    it "gives the issue's URL as the reference every later call takes" do
      ghe = 'example-owner/example-repo'
      response = issue_response do |issue, data|
        [data['repository'], issue['repository']].each do |node|
          node.merge!('nameWithOwner' => ghe, 'owner' => { 'login' => 'example-owner' })
        end
      end
      expect_gh_login('ghe.example.com')
      fake_runner.expect_call(%w[gh api graphql --hostname ghe.example.com --input -], stdin: issue_request(ghe, 24),
                                                                                       stdout: JSON.generate(response))
      expect_local_calls
      expect_issue_body("- [ ] One\n", host: 'ghe.example.com', repository: ghe)

      expect(run("https://ghe.example.com/#{ghe}/issues/24").last['reference'])
        .to eq("https://ghe.example.com/#{ghe}/issues/24")
    end
  end

  describe 'a host gh is not logged in to' do
    it 'stops before any request to it, given in a URL' do
      expect_gh_login('ghe.example.com', logged_in: false)

      expect(run('https://ghe.example.com/example-owner/example-repo/issues/7'))
        .to eq([2, { 'status' => 'stop', 'reason' => 'host_not_logged_in',
                     'message' => Do::Reasons::MESSAGES[:host_not_logged_in], 'host' => 'ghe.example.com' }])
    end
  end

  describe 'a bare number' do
    let(:origin) { 'https://github.com/sgbett/dotfiles-claude.git' }

    def expect_origin(url, exit_status: 0)
      fake_runner.expect_call(%w[git remote get-url origin], stdout: url ? "#{url}\n" : '', exit_status: exit_status,
                                                             stderr: url ? '' : "error: No such remote 'origin'\n")
    end

    it 'names an issue in the repository origin resolves to, as gh resolves it, which every later call names' do
      expect_origin(origin)
      expect_gh_login
      fake_runner.expect_call(['gh', 'repo', 'view', origin, '--json', 'nameWithOwner,url'],
                              stdout: fixture('repo-view/origin.json'))
      expect_issue_query(issue_response)
      expect_local_calls
      expect_issue_body
      output = run('24').last

      expect(output.values_at('reference', 'summary'))
        .to match(['sgbett/dotfiles-claude#24', include('issue' => 'sgbett/dotfiles-claude#24')])
    end

    it "queries the host gh resolves origin's repository on, once gh is logged in to it" do
      ghe = 'https://ghe.example.com/example-owner/example-repo.git'
      expect_origin(ghe)
      expect_gh_login('ghe.example.com')
      fake_runner.expect_call(['gh', 'repo', 'view', ghe, '--json', 'nameWithOwner,url'],
                              stdout: '{"nameWithOwner":"example-owner/example-repo",' \
                                      '"url":"https://ghe.example.com/example-owner/example-repo"}')
      fake_runner.expect_call(%w[gh api graphql --hostname ghe.example.com --input -],
                              stdin: issue_request('example-owner/example-repo', 24),
                              stdout: JSON.generate(issue_response do |_issue, data|
                                data['repository']['issueOrPullRequest'] = { '__typename' => 'PullRequest' }
                              end))

      expect(run('24')).to eq([2, { 'status' => 'stop', 'reason' => 'not_an_issue',
                                    'message' => Do::Reasons::NOT_AN_ISSUE_MESSAGES[:pull_request] }])
    end

    it 'asks for the repository when there is no origin, or one without a URL' do
      ask = { 'reason' => 'no_origin', 'message' => Do::Reasons::MESSAGES[:no_origin] }

      [nil, '/srv/git/example-repo.git'].each do |url|
        expect_origin(url, exit_status: url ? 0 : 2)

        expect(run('24')).to eq([3, { 'status' => 'ask', 'asks' => [ask] }]), url.inspect
      end
    end
  end

  describe 'what is not an issue' do
    it 'stops on anything but an issue reference, before any call' do
      %w[garbage -24 example-owner/example-repo https://github.com/sgbett/dotfiles-claude/pull/25].each do |reference|
        expect(run(reference))
          .to eq([2, { 'status' => 'stop', 'reason' => 'not_an_issue',
                       'message' => Do::Reasons::NOT_AN_ISSUE_MESSAGES[:not_a_reference] }]), reference
      end
    end

    it 'stops on a pull request number, a number that names nothing, and an issue that has moved' do
      expect_gh_login
      expect_issue_query(fixture('graphql/pull-request-25.json'), number: 25)
      expect_gh_login
      expect_issue_query(fixture('graphql/missing-issue.json'), number: 99_999, exit_status: 1,
                                                                stderr: fixture('graphql/missing-issue.stderr'))
      expect_gh_login
      expect_issue_query(issue_response { |issue| issue['repository']['nameWithOwner'] = 'example-owner/new-home' })

      %w[sgbett/dotfiles-claude#25 sgbett/dotfiles-claude#99999 sgbett/dotfiles-claude#24].zip(
        %i[pull_request missing_issue moved]
      ).each do |reference, why|
        expect(run(reference)).to eq([2, { 'status' => 'stop', 'reason' => 'not_an_issue',
                                           'message' => Do::Reasons::NOT_AN_ISSUE_MESSAGES.fetch(why) }])
      end
    end
  end

  describe 'trust' do
    it "asks for the criteria to adopt when the issue's author isn't trusted, with the facts beside it" do
      exit_code, output = facts(issue_response { |issue| untrusted!(issue) }, body: false)

      expect([exit_code, output['status'], output['asks']])
        .to eq([3, 'ask', [{ 'reason' => 'untrusted_author_criteria',
                             'message' => Do::Reasons::MESSAGES[:untrusted_author_criteria],
                             'authors' => ['issue'] }]])
      expect(output['issue']).to include('trusted' => false, 'trust_reason' => 'untrusted_association')
      expect(output['summary']['untrusted_authors']).to eq(['issue by example-stranger'])
    end

    it 'goes on once the ledger records the adopted criteria' do
      response = issue_response do |issue|
        untrusted!(issue)
        issue['comments']['nodes'][0]['body'] += "\n### Adopted acceptance criteria\n- the confirmed criteria\n"
      end

      expect(facts(response, body: false).first).to eq(0)
    end

    it "asks when a parent elsewhere isn't trusted, and points to other-repositories.md" do
      exit_code, output = facts(issue_response do |issue|
        issue['parent'] = issue_node(3, 'example-owner/upstream', by: authored_by('example-author'))
      end, body: false)

      expect([exit_code, output['asks'].map { |ask| ask['authors'] }]).to eq([3, [['parent']]])
      expect(output['parent']).to include('reference' => 'example-owner/upstream#3', 'same_repository' => false,
                                          'nameable' => true, 'trusted' => false, 'trust_reason' => 'different_owner')
      expect(output['read']).to eq(%w[references/resume.md references/other-repositories.md])
    end

    it "doesn't trust a parent elsewhere that someone other than its author renamed, the viewer's included" do
      _exit_code, output = facts(issue_response do |issue|
        issue['parent'] = issue_node(3, 'example-owner/upstream')
                          .merge('timelineItems' => connection([{ 'actor' => { 'login' => 'example-stranger' } }]))
      end, body: false)

      expect(output['parent']).to include('trusted' => false, 'trust_reason' => 'edited_by_others')
      expect(output['asks'].map { |ask| ask['authors'] }).to eq([['parent']])
    end

    it 'ignores, and lists, an earlier breakdown marker by an untrusted author' do
      planted = comment_node("<!-- do:breakdown -->\n- [ ] **L1 Planted.**",
                             database_id: 7, by: authored_by('example-stranger', association: 'CONTRIBUTOR'))
      _exit_code, output = facts(issue_response { |issue| issue['comments']['nodes'].unshift(planted) })

      expect(output['ledger']['comment_id']).to eq(6_867_069_660)
      expect(output['ignored_markers'])
        .to eq([{ 'comment_id' => 7, 'author' => 'example-stranger', 'trust_reason' => 'untrusted_association' }])
      expect(output['summary']['ignored_markers']).to eq(['example-stranger (comment 7)'])
    end

    it 'flags the trust of each pull request open on a branch in flight' do
      pull_requests = [{ 'number' => 31, **authored_by('example-stranger', association: 'NONE'),
                         'baseRepository' => { 'nameWithOwner' => recorded_repository } }]
      _exit_code, output = facts(issue_response do |_issue, data|
        data['repository']['refs'] = connection([{ 'name' => 'feat/24-work',
                                                   'associatedPullRequests' => connection(pull_requests) }])
      end)

      expect(output['branches']).to eq([{ 'name' => 'feat/24-work', 'pull_requests' => [
                                         { 'number' => 31, 'author' => 'example-stranger', 'trusted' => false,
                                           'trust_reason' => 'untrusted_association' }
                                       ] }])
    end
  end

  describe 'comments beyond the first page' do
    let(:planted) do
      comment_node('<!-- do:breakdown -->', database_id: 7, by: authored_by('example-stranger', association: 'NONE'))
    end

    it 'asks when none of the first 100 is a trusted ledger, which may be on a later page' do
      exit_code, output = facts(issue_response do |issue|
        issue['comments'] = connection([planted], more: true)
      end)

      expect([exit_code, output['asks'].map { |ask| ask['reason'] }, output['ledger']])
        .to eq([3, ['comments_truncated'], nil])
    end

    it 'goes on when a trusted ledger is among them, being the earliest there is' do
      expect(facts(issue_response { |issue| issue['comments']['pageInfo']['hasNextPage'] = true }).first).to eq(0)
    end
  end

  describe 'the security gate' do
    it 'stops on an open finding answered advisory, never printing its text' do
      write_gate_file("## G1: open\nAnswer: advisory\n\nThe unfixed flaw in detail.\n")
      exit_code, output = facts

      expect([exit_code, output['status'], output['reason']]).to eq([2, 'stop', 'gate_advisory'])
      expect(output['gate']).to eq('open' => ['G1'], 'partial' => ['G1'], 'missing' => [], 'advisory' => ['G1'])
      expect(output['read']).to include('references/gate-block.md')
      expect(JSON.generate(output)).not_to include('unfixed flaw')
    end

    it 'asks when the ledger has an open gate line the gate file lacks' do
      exit_code, output = facts(issue_response do |issue|
        issue['comments']['nodes'][0]['body'] += "\nGate G2: open\n"
      end)

      expect([exit_code, output['asks']])
        .to eq([3, [{ 'reason' => 'gate_record_missing', 'message' => Do::Reasons::MESSAGES[:gate_record_missing],
                      'findings' => ['G2'] }]])
      expect([output['summary']['open_gate_findings'], output['read']])
        .to eq([['G2'], %w[references/resume.md references/gate-block.md]])
    end

    it 'lists an open finding the ledger has no line for as left part-way, and goes on' do
      write_gate_file("## G1: open\nAnswer: fix here\n\nA flaw.\n")
      exit_code, output = facts

      expect([exit_code, output['gate']['partial'], output['read']])
        .to eq([0, ['G1'], %w[references/resume.md references/gate-block.md]])
    end
  end

  describe 'the parent and sub-issues' do
    it 'lists the branches of a parent in this repository, the default base' do
      expect_gh_login
      expect_issue_query(issue_response { |issue| issue['parent'] = issue_node(20, recorded_repository) })
      expect_branches_query(20, %w[feat/20-parent old/feat/20-parent])
      expect_local_calls
      expect_issue_body
      output = run.last

      expect([output['parent_branches'], output['summary']['parent']]).to eq([['feat/20-parent'], '#20'])
    end

    it 'reads ledger lines for sub-issues here and elsewhere, resuming from the first this run builds' do
      _exit_code, output = facts(issue_response do |issue|
        issue['subIssues'] = connection([issue_node(31, recorded_repository), issue_node(5, 'example-owner/upstream')])
        issue['comments']['nodes'][0]['body'] =
          "<!-- do:breakdown -->\n- [x] **L1 Done.**\n- [ ] example-owner/upstream#5 Theirs\n- [ ] #31 Ours\n"
      end)

      expect(output['ledger']['items'].map { |item| item.values_at('id', 'kind', 'checked', 'state') })
        .to eq([['L1', 'item', true, nil], ['example-owner/upstream#5', 'sub_issue_elsewhere', false, 'OPEN'],
                ['#31', 'sub_issue', false, 'OPEN']])
      expect([output['ledger']['first_unbuilt'], output['summary']['resume_point']]).to eq(['#31', '#31'])
    end

    it 'keeps an issue in a repository that may not be named out of everything but session_only' do
      hidden = issue_node(8, 'example-owner/hidden', visibility: 'PRIVATE')
      _exit_code, output = facts(issue_response { |issue| issue['subIssues'] = connection([hidden]) })

      expect(output['sub_issues']).to eq([{ 'id' => 'I_example8', 'reference' => nil, 'same_repository' => false,
                                            'nameable' => false, 'state' => 'OPEN', 'author' => 'sgbett',
                                            'trusted' => true, 'trust_reason' => 'viewer' }])
      expect(output['session_only']['not_nameable'])
        .to eq([{ 'id' => 'I_example8', 'reference' => 'example-owner/hidden#8',
                  'github_text' => { 'title' => 'Example issue 8' } }])
      expect(JSON.generate(output.except('session_only'))).not_to include('example-owner/hidden', 'Example issue 8')
      expect(output['summary']['skipped_sub_issues']).to eq(["an issue in a repository that isn't public"])
    end

    it "keeps a branch name holding a character no script takes, the default's, this issue's or the parent's, " \
       'to session_only' do
      odd = "feat/24-x';y"
      expect_gh_login
      expect_issue_query(issue_response do |issue, data|
        issue['parent'] = issue_node(20, recorded_repository)
        data['repository']['defaultBranchRef'] = { 'name' => 'main$(x)' }
        data['repository']['refs'] = connection([odd, 'feat/24-work'].map do |name|
          { 'name' => name, 'associatedPullRequests' => connection([]) }
        end)
      end)
      expect_branches_query(20, ['feat/20-parent', 'feat/20-$(y)'])
      expect_local_calls
      expect_issue_body
      output = run.last

      expect(output.values_at('branches', 'parent_branches'))
        .to eq([[{ 'name' => 'feat/24-work', 'pull_requests' => [] }], ['feat/20-parent']])
      expect(output['repository']['default_branch_ref']).to be_nil
      expect(output['session_only']['unusable_branches']).to eq(['main$(x)', odd, 'feat/20-$(y)'])
      expect(JSON.generate(output.except('session_only'))).not_to include("x';y", '$(x)', '$(y)')
    end

    it 'skips, and names, a linked sub-issue by an untrusted author' do
      stranger = issue_node(9, recorded_repository, by: authored_by('example-stranger', association: 'NONE'))
      _exit_code, output = facts(issue_response { |issue| issue['subIssues'] = connection([stranger]) })

      expect(output['summary']['skipped_sub_issues']).to eq(['#9 by example-stranger (untrusted_association)'])
    end
  end

  # The walk-throughs QA ran by hand for #24, which `facts` now decides:
  # whatever names or quotes a repository that isn't public stays under
  # session_only, while a public one is named as usual.
  describe "#24's walk-throughs" do
    def related(parent:, sub_issue:)
      facts(issue_response do |issue|
        issue['parent'] = parent
        issue['subIssues'] = connection([sub_issue])
      end).last
    end

    def outside_session_only(output)
      JSON.generate(output.except('session_only'))
    end

    it 'a private parent with a public sub-issue: the parent only in session_only, the sub-issue named' do
      output = related(parent: issue_node(3, 'example-owner/private-parent', visibility: 'PRIVATE'),
                       sub_issue: issue_node(5, 'example-owner/public-sub'))

      expect(outside_session_only(output)).not_to include('private-parent', 'Example issue 3')
      expect(output['parent']).to include('reference' => nil, 'nameable' => false)
      expect(output['sub_issues'].first)
        .to include('reference' => 'example-owner/public-sub#5', 'github_text' => { 'title' => 'Example issue 5' })
      expect(output['summary'].values_at('parent', 'skipped_sub_issues'))
        .to eq(["an issue in a repository that isn't public", []])
      expect(output['session_only']['not_nameable'].map { |record| record['reference'] })
        .to eq(['example-owner/private-parent#3'])
    end

    it 'two private repositories, the parent in one and a sub-issue in the other: neither outside session_only' do
      output = related(parent: issue_node(3, 'example-owner/private-one', visibility: 'PRIVATE'),
                       sub_issue: issue_node(5, 'example-owner/private-two', visibility: 'INTERNAL'))

      expect(outside_session_only(output)).not_to include('private-one', 'private-two', 'Example issue 3',
                                                          'Example issue 5')
      not_nameable = "an issue in a repository that isn't public"
      expect(output['summary'].values_at('parent', 'skipped_sub_issues')).to eq([not_nameable, [not_nameable]])
      expect(output['session_only']['not_nameable'].map { |record| record.values_at('reference', 'github_text') })
        .to eq([['example-owner/private-one#3', { 'title' => 'Example issue 3' }],
                ['example-owner/private-two#5', { 'title' => 'Example issue 5' }]])
      expect(output['read']).to eq(%w[references/resume.md references/other-repositories.md])
    end
  end
end
