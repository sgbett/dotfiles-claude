# /repo-consistency spec fixtures

What these files are, and the policy every fixture follows, is in [`skills/_support/spec/fixtures/README.md`](../../../_support/spec/fixtures/README.md). In short: the raw output of one read-only `gh` call against a public repository, or synthesised by hand.

## Recorded

Each was recorded from the repository root of a checkout of sgbett/dotfiles-claude on 2026-11-18, the trees on 2026-11-19, after checking that `gh repo view sgbett/bsv-ruby-sdk --json visibility` printed `PUBLIC`. The commands are the exact calls `git-settings audit` makes (`RepositoryReader` and `SkillScanReader`, through `SkillSupport::Gh#api` and `RepositoryFiles#read`), so the gh shim and the fake runner match them argument for argument.

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
gh api --hostname github.com -X GET repos/sgbett/bsv-ruby-sdk/git/trees/master > $F/trees/bsv-ruby-sdk-master.json
gh api --hostname github.com -X GET repos/sgbett/bsv-ruby-sdk/git/trees/eecdcc7a616b52dd805c6b3cda68eeb89907ccd6 \
  -f recursive=1 > $F/trees/bsv-ruby-sdk-claude.json
```

`rulesets/ruleset-scratch-<id>.json` were recorded on 2026-11-24 from sgbett/ruleset-scratch, a public scratch repository made to try the three ruleset templates, which no longer exists, with the read `RepositoryReader` makes for each ruleset's detail, once the templates were applied:

```sh
for id in 28033488 28033490 28033491; do
  gh api --hostname github.com -X GET repos/sgbett/ruleset-scratch/rulesets/$id > $F/rulesets/ruleset-scratch-$id.json
done
```

They are GitHub's detail of `Git workflow`, `Project and release branches` and `Tags` as applied: as written, except that the `pull_request` rule gains `required_reviewers: []`, which is why the audit compares only the parameters a template states.

`repos/bsv-ruby-sdk.json` is the repository as it stood: on `master`, squash and rebase merges allowed beside merge commits, the update-branch button off. `rules/bsv-ruby-sdk-master.json` is what is in force on `master`: a `required_status_checks` rule and a `copilot_code_review` rule, from two rulesets, and none of the template's three. `rulesets/bsv-ruby-sdk.json` lists those two rulesets, `Block unless CI green` and `Copilot review for default branch`, and `rulesets/bsv-ruby-sdk-<id>.json` is each one's detail, both granting a bypass to a repository role, which the list leaves out. `protection/bsv-ruby-sdk-master.json` and its `.stderr` are the 404 GitHub gives, exiting 1, for a branch with no classic protection, "Branch not protected", which the reader takes to mean none and nothing else. `contents/not-found.json` and its `.stderr` are the 404 for a path the default branch lacks, recorded for `.claude/rules/git-workflow.md`, which answers any file a synthesised repository lacks. `trees/bsv-ruby-sdk-master.json` is the default branch's root tree, listing `CLAUDE.md` and the `.claude` directory under the id the second command reads, and `trees/bsv-ruby-sdk-claude.json` is that directory's whole tree. Neither is truncated or holds a symlink or submodule, and `.claude` has no `CLAUDE.md` or `rules/`, so the skill-name check reads nothing after them; its `skills/` holds a Markdown file but no skill directory.

`CLAUDE.md` is not recorded. The file exists on `master`, with no tier line, but it names clone paths under `/opt` and repositories outside the fixture allowlist, which the contents API returns in base64 that `fixture_policy_spec.rb` cannot read; the specs stand a short synthesised `CLAUDE.md` without a tier line in its place (`RecordedRun::SYNTHESISED_CLAUDE_MD`), which names no skill. The recorded run also answers the rules file's read with a synthesised vendored copy (`RecordedRun::SYNTHESISED_RULES_FILE`), so that the repository is protected and the run exercises every check a protected repository gets; the recorded trees don't list it, so the skill-name check doesn't read it.

The `repos` recording carries the recording account's `permissions` on the repository, which the audit does not read; they say only that the owner administers their own repository.

## Synthesised

The specs build every other case in Ruby (`spec/support/template_fixture.rb`, `spec/support/repository_answers.rb` and the specs themselves) from the recorded shapes, under `example-owner/` names: a repository compliant with the template and its vendored files, one with a classic protection that adds nothing and one whose protection adds reviews, status checks or push restrictions, a ruleset granting a bypass under a plain name and under one that is not plain, a Copilot-only ruleset with squash merges on, a `pull_request` rule allowing other merge methods and requiring approvals, `required_linear_history` in force, a personal repository with and without `pull_request` rules, tier lines stating no difference or a word other than the tier, a template's ruleset with other patterns or enforcement, a default branch of `main`, a vendored rules file with a changed line, another header or a third header line, the 403 naming the plan that GitHub gives a private repository on a free plan (no public repository can), a repository gh cannot read, bad credentials, a ruleset list that fills a page, instruction files (`CLAUDE.md`, `.claude/CLAUDE.md`, a nested rules file, a `claude.md` and a `.claude/Rules/Team.MD`) naming skills, a skill or command shipped under `.claude/`, a skill directory without `SKILL.md`, a `SKILL.md` or command linked to a file in the repository or out of it, a linked skill of the repository's own, a truncated root or `.claude` tree, a `.claude` id that isn't an object id, a symlinked directory or a submodule where the skill-name check looks, a `CLAUDE.md`, rules file or command symlinked to a file in the repository, which the contents API reads through, a rules file symlinked out of it, which the API answers with `"type": "symlink"`, a rules file over the API's 1 MB limit, which it answers with `"encoding": "none"` and empty content, a 502 or a secondary rate limit's 403 on an instruction file's read, and gh printing something other than JSON. The template fixture itself restates the real template's JSON with a short profile, so that a spec controls every byte compared; `drift_spec.rb` holds the real `profiles/git-workflow` to the same checks, and compares it with the `ruleset-scratch` recordings, as recorded and changed.
