# /repo-consistency spec fixtures

What these files are, and the policy every fixture follows, is in [`skills/_support/spec/fixtures/README.md`](../../../_support/spec/fixtures/README.md). In short: the raw output of one read-only `gh` call against a public repository, or synthesised by hand.

## Recorded

Each was recorded from the repository root of a checkout of sgbett/dotfiles-claude on 2026-11-18, the tree on 2026-11-19, after checking that `gh repo view sgbett/bsv-ruby-sdk --json visibility` printed `PUBLIC`. The commands are the exact calls `git-settings audit` makes (`RepositoryReader` and `SkillScanReader`, through `SkillSupport::Gh#api` and `RepositoryFiles#read`), so the gh shim and the fake runner match them argument for argument.

```sh
F=skills/repo-consistency/spec/fixtures

gh api --hostname github.com -X GET repos/sgbett/bsv-ruby-sdk > $F/repos/bsv-ruby-sdk.json
gh api --hostname github.com -X GET repos/sgbett/bsv-ruby-sdk/rules/branches/master -f per_page=100 \
  > $F/rules/bsv-ruby-sdk-master.json
gh api --hostname github.com -X GET repos/sgbett/bsv-ruby-sdk/rulesets -f per_page=100 > $F/rulesets/bsv-ruby-sdk.json
gh api --hostname github.com -X GET repos/sgbett/bsv-ruby-sdk/rulesets/15226411 > $F/rulesets/bsv-ruby-sdk-15226411.json
gh api --hostname github.com -X GET repos/sgbett/bsv-ruby-sdk/rulesets/14583984 > $F/rulesets/bsv-ruby-sdk-14583984.json
gh api --hostname github.com -X GET repos/sgbett/bsv-ruby-sdk/branches/master/protection \
  > $F/protection/bsv-ruby-sdk-master.json 2> $F/protection/bsv-ruby-sdk-master.stderr
gh api --hostname github.com -X GET repos/sgbett/bsv-ruby-sdk/contents/.claude/rules/git-workflow.md -f ref=master \
  > $F/contents/not-found.json 2> $F/contents/not-found.stderr
gh api --hostname github.com -X GET repos/sgbett/bsv-ruby-sdk/git/trees/master -f recursive=1 \
  > $F/trees/bsv-ruby-sdk-master.json
```

`repos/bsv-ruby-sdk.json` is the repository as it stood: on `master`, squash and rebase merges allowed beside merge commits, the update-branch button off. `rules/bsv-ruby-sdk-master.json` is what is in force on `master`: a `required_status_checks` rule and a `copilot_code_review` rule, from two rulesets, and none of the template's three. `rulesets/bsv-ruby-sdk.json` lists those two rulesets, `Block unless CI green` and `Copilot review for default branch`, and `rulesets/bsv-ruby-sdk-<id>.json` is each one's detail, both granting a bypass to a repository role, which the list leaves out. `protection/bsv-ruby-sdk-master.json` and its `.stderr` are the 404 GitHub gives, exiting 1, for a branch with no classic protection, "Branch not protected", which the reader takes to mean none and nothing else. `contents/not-found.json` and its `.stderr` are the 404 for a path the default branch lacks, recorded for `.claude/rules/git-workflow.md`; the reads of `.claude/hooks/push-guard`, `.claude/hooks/push-guard.rb` and `.claude/settings.json` printed the same bytes on stdout and stderr, checked with `cmp`, so this one recording answers all four. `trees/bsv-ruby-sdk-master.json` is the default branch's whole tree, not truncated, with no symlink or submodule: it lists `CLAUDE.md` but no `.claude/CLAUDE.md` or `.claude/rules/`, so the skill-name check reads nothing after it, and its `.claude/skills/` holds a Markdown file but no skill directory.

`CLAUDE.md` is not recorded. The file exists on `master`, with no tier line, but it names clone paths under `/opt` and repositories outside the fixture allowlist, which the contents API returns in base64 that `fixture_policy_spec.rb` cannot read; the specs stand a short synthesised `CLAUDE.md` without a tier line in its place (`ScriptCalls::UNDECLARED_CLAUDE_MD`), which gives the same `undeclared` outcome and names no skill.

The `repos` recording carries the recording account's `permissions` on the repository, which the audit does not read; they say only that the owner administers their own repository.

## Synthesised

The specs build every other case in Ruby (`spec/support/template_fixture.rb`, `spec/support/repository_answers.rb` and the specs themselves) from the recorded shapes, under `example-owner/` names: a repository compliant with the template and its vendored files, one with a classic protection that adds nothing and one whose protection adds reviews, status checks or push restrictions, a ruleset granting a bypass under a plain name and under one that is not plain, a Copilot-only ruleset with squash merges on, a `pull_request` rule allowing other merge methods and requiring approvals, `required_linear_history` in force, a personal repository with and without `pull_request` rules, a default branch of `main`, a vendored rules file with a changed line, another header or a third header line, hook files missing or changed, a settings file without the entry or not JSON, the 403 naming the plan that GitHub gives a private repository on a free plan (no public repository can), a repository gh cannot read, bad credentials, a ruleset list that fills a page, instruction files (`CLAUDE.md`, `.claude/CLAUDE.md`, a nested rules file) naming skills, a skill or command shipped under `.claude/`, a truncated tree, a symlink or submodule where the skill-name check looks, and a rules file over the contents API's 1 MB limit, which it answers with `"encoding": "none"` and empty content. The template fixture itself restates the real template's JSON with a short profile and short hooks, so that a spec controls every byte compared; `drift_spec.rb` holds the real `profiles/git-workflow` to the same checks.
