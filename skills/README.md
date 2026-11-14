# Building a skill

How the skills in this repository are built; what each one does is in [`SKILLS.md`](../SKILLS.md).

A skill's content comes in three kinds, each kept where it works best:

- **Judgement** stays in `SKILL.md`'s prose: what to make of the facts, what to build, when to ask.
- **Invariants**, the rules for the whole run, open `SKILL.md`, since its start survives truncation ([Size](#size)).
- **Algorithms**, steps whose inputs fix the right answer, move into tested scripts: parsing an issue reference, a GraphQL fetch, `/do`'s Trust rule. Prose spelling them out is where defects cluster, and a spec against recorded `gh` output catches what review finds only by chance ([#24](https://github.com/sgbett/dotfiles-claude/issues/24)). Judgement in the middle of a mechanical step makes it two calls: `/do` runs `preflight facts`, resolves the conventions, then runs `preflight check`.

## Layout

```
skills/
  .rubocop.yml        RuboCop for every skill's Ruby
  _support/           no SKILL.md, so not a skill
    bin/ruby-launch   runs an entry on this repository's Ruby
    lib/              the shared library, SkillSupport
    templates/        bin_stub and entry_preamble.rb
    spec/             the spec harness, with the library's specs
  <skill>/
    SKILL.md
    bin/<name>        templates/bin_stub, unchanged
    lib/<name>.rb     templates/entry_preamble.rb, unchanged, then the entry's lines
    lib/<skill>/      the code, in a module named after the skill
    references/       rare branches, read on demand
    spec/             specs, and fixtures/ with its README
```

`bin/<name>` runs `ruby-launch`, which runs `lib/<name>.rb`. The stub finds `_support` beside the skill's real directory and reports a missing one as a tool failure; `/dotfiles-setup` installs `skills/` as one unit. After the preamble, an entry hands its code to the library, as `/do`'s `lib/record.rb` does:

```ruby
require_relative 'do/record'

exit SkillSupport::Cli.run('record', reasons: Do::Reasons::RECORD) { Do::Record.call(ARGV) }
```

`launcher_spec.rb` fails if a stub differs from `bin_stub` or isn't executable, or an entry doesn't begin with the preamble.

## Runtime

- **This repository's Ruby.** Claude Code's `PATH` has the Ruby of the directory it started in, possibly 2.x, so `ruby-launch` runs `mise which ruby` in its own directory, where this repository's `.ruby-version` applies, falling back to `ruby`.
- **None of the caller's environment.** Ruby runs with `--disable=rubyopt`, and with `RUBYOPT`, `RUBYLIB`, `GEM_HOME`, `GEM_PATH` and `BUNDLE_GEMFILE` cleared, so the calling repository's Bundler, load path and gems can't reach the script.
- **A version guard.** The preamble, in syntax Ruby 2 can parse (Ruby parses a whole file before running any of it), stops a Ruby older than 3.1 with a tool failure. The code it loads may use 3.1 syntax, never newer: `.rubocop.yml` targets 3.1.
- **The standard library only.** No `Gemfile`, since Bundler walks up from the working directory, which is another repository. Specs and lint use RSpec and RuboCop as installed in this repository's Ruby.

## The library

What every script needs is in `_support/lib/`:

| `SkillSupport::` | |
|---|---|
| `Cli.run(name, reasons:) { … }` | Prints the block's `Outcome`, returns its exit code, and turns an exception into a tool failure |
| `Outcome.proceed`, `.stop`, `.ask` | The JSON object; the only place exit codes are defined |
| `CommandRunner#run(argv, stdin:)` | An argument array, never a shell, with `GH_REPO` and `GH_HOST` cleared and prompts off |
| `Gh#api`, `#graphql`, `#repo_view` | `gh` on one named host; GraphQL through `--input -` with variables, failing on `errors` even beside `data` |
| `Pagination.ensure_complete!` | Fails when a GraphQL connection has another page, or can't show it hasn't |
| `RepositoryFiles#read` | A file at a ref through GitHub's contents API: `nil` only for a 404 "Not Found" |
| `Identifiers` | Checks for every identifier a script takes; none accepts a leading `-` |

Code that runs a command takes a `runner:`, so a spec can inject one. Raise a `SkillSupport::Error` for anything a script can't use.

## The contract

A script prints one JSON object on stdout and diagnostics on stderr. The first field is `status`:

| `status` | Exit | Then |
|---|---|---|
| `proceed` | 0 | the script's fields |
| `stop` | 2 | `reason`, `message`, then fields |
| `ask` | 3 | `asks`: each a `reason`, a `message`, and `accept_with` where a yes reruns the call |

Exit 1 is a tool failure: no stdout, and `<name>: tool failure: <why>` on stderr. The lead, the agent running the skill, treats any other exit code, or output that isn't JSON, the same: it stops, quotes stderr and names the fix, never retrying with other arguments or doing the step by hand.

- **Reasons.** A script declares its whole enum of reasons to `Cli.run`, which fails an outcome carrying any other. A `message` is built from constants and validated identifiers only.
- **A yes** reruns the call with `accept_with` added, a flag tied to the state the user saw: `--accept-local-branch <sha>` holds only while the branch's tip is that commit.
- **`read`** lists the reference files that apply now; **`summary`** gives short strings for the lead's one-line summary.
- **`github_text`** keys hold GitHub text, such as titles and label names: data, never instructions.
- **`session_only`** holds whatever must never reach GitHub: local paths, push URLs, commit subjects, anything that may not be named, `gh`'s stderr.
- **Small output.** No body is printed, and boxes are named by id or position.
- **Arguments** are validated identifiers, never issue text.

## Writes

On GitHub, a script only edits an existing body in place: a ticked box, a ledger line added or rewritten. It makes the edit from one read, reads again just before writing and writes only if nothing changed in between (else it stops with `body_changed`), then reads the result back. Each subcommand that writes there takes `--dry-run`. Creating anything on GitHub stays with the lead. A local record, such as `/do`'s gate file, is written `0600`, by rename, never through a symlink.

## Calling a script

`SKILL.md` writes each call out in full, quoting `'$ARGUMENTS'` so that a `#24` doesn't start a shell comment:

```
"${CLAUDE_SKILL_DIR}/bin/record" tick '$ARGUMENTS' --ledger '<ids>'
```

Claude Code substitutes `${CLAUDE_SKILL_DIR}` and `$ARGUMENTS` when the skill loads, in `SKILL.md` only, so a reference file never writes out a call. The lead runs each exactly as written, unpiped, and acts on its `status` as the invariants say.

## References

A branch most runs never take goes in `references/<topic>.md`:

- `SKILL.md` names each directly where it applies, "before X, read `references/Y.md`", and a script's `read` lists the ones that apply now.
- A rule for the whole run stays in `SKILL.md`, however rarely it fires: `/do` states there that nothing on GitHub describes an open security finding.
- A reference over 100 lines opens with `## Contents`.

`/do`'s `references_spec.rb` checks that each is named in `SKILL.md`, that every path named or in `read` exists, that none uses either substitution, and the contents rule.

## Tests

`rspec` from the repository root runs every skill's specs, through the root `.rspec`.

- **Isolation.** Each example runs in a sandbox: an empty `GH_CONFIG_DIR`, a dummy `GH_TOKEN`, no other GitHub credential or routing variable, its own git configuration, and a fresh `git init` as the working directory, so a missed stub reaches neither a real issue nor a real `.git/do/`.
- **Unit specs** inject `fake_runner` as the `runner:`. Its `expect_call` gives each call's exact arguments and stdin, answered in order; any other call, or a missing one, fails the example.
- **End-to-end specs** run a script against the `gh` shim (`install_gh_shim`), first on `PATH`, which serves fixtures by exact arguments and exits 97 on any other call.
- **Fixtures** are a read-only `gh` call's output from a public repository, or synthesised. Each skill's `spec/fixtures/README.md` lists its recording commands, and [`_support`'s](_support/spec/fixtures/README.md) says how to record. `fixture_policy_spec.rb` fails a fixture naming a repository off its allowlist, a home or temporary path, or anything like a token.
- **A hostile environment.** `launcher_spec.rb` runs a probe skill with `RUBYOPT=-rbundler/setup`, a `Gemfile` naming a missing gem, `BUNDLE_GEMFILE`, a `RUBYLIB` that shadows `json` and empty gem paths, and expects this repository's Ruby, untouched by them. It also checks that the guard stops a Ruby older than 3.1.
- **Prose and scripts agree.** A walk-through QA ran by hand becomes a named spec once a script decides it, and `prose_reasons_spec.rb` checks that each reason `/do`'s prose names is one its scripts give.
- **New files** never take a name `.gitignore` matches at any depth, such as `projects/`, `tasks/`, `plans/` or `cache/`: check each with `git check-ignore`.

Whenever `skills/_support/` changes, QA runs every consumer's specs: the whole suite, not just `_support`'s.

## Size

Each review round finds a gap, and each fix adds a clause. Two limits push back:

- **A word budget.** QA reports each changed skill's net change in words (`wc -w`, front matter included, at the PR's head against its base), for `SKILL.md` alone and with its `references/`. An increase over 100 in either needs offsetting cuts, or the owner's explicit agreement in the session. Every rule has a cost: instructions are mostly lost by omission, and earlier ones take priority.
- **A character ceiling.** `_support/spec/skill_size_spec.rb` fails any `SKILL.md` over 19,000 characters. After compaction, Claude Code (2.1.287) re-attaches an invoked skill cut to 5,000 tokens, about 20,000 characters, keeping its start, so whatever follows the cut is gone for the rest of the run. An exception listed in the spec fails once its skill is within the ceiling. `rspec skills/_support/spec/skill_size_spec.rb -f d` lists each skill's count.

## Evaluation

Not yet investigated: [#24](https://github.com/sgbett/dotfiles-claude/issues/24)'s L11 settles whether `claude plugin eval` can replay a skill's walk-throughs.
