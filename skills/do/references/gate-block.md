# A blocking security finding

`/do`'s step 6 from the moment the white-hat reports a Critical or High finding until step 7 marks it, and any resume while one is open. Run each `bin/record gate` call as SKILL.md writes it (step 6, and step 7 for `gate mark`), with the values below, and handle its output as SKILL.md's invariants say.

## Record it at once

Record each new block before any fix, even with no PR yet:

1. **File it.** Write the finding as reported to a session-scratchpad file with the Write tool, and pass that file to `gate add`. It files the finding in the local gate file under the lowest id free there and in the ledger, and prints that id as `k` (`G1`, `G2`, …), which the later calls take as `--k`.
2. **Ask the owner, on a public repository only** (`facts`' `repository.visibility`): whether to fix it here or stop so the owner can use a private security advisory (`/do` never opens one), saying whether the flaw predates the branch. Ask in the session, never on GitHub, and record the answer with `gate answer` (`fix-here` or `advisory`); once it's given, only the owner changes it (reason `gate_answered`). On `advisory`, stop the run, pushing nothing.
3. **Publish it.** `gate publish` adds the plain ledger line `Gate G<k>: open`. It never does for a finding answered advisory (reason `gate_advisory`), and on a public repository it asks for the owner's answer first (reason `gate_unanswered`).

A finding is open while the gate file or the ledger says so.

## While it's open

- **Nothing on GitHub describes a finding or names its file or trigger until its fix is pushed, or ever if the user decided to leave it:** no ledger item, rewind or blocker comment. Brief whoever fixes it to report blockers to you.
- It blocks the PR until it's fixed and re-checked, or the user decides in the session (never via GitHub) to leave it, once told the PR will then say `Security gate: ran, FAIL`.
- Every security review while a finding is open starts with the white-hat re-checking each open finding in the gate file (`facts`' `session_only.gate_file`) as fixed, open or can't tell, where only fixed clears one; then it reviews as usual.
- If the ledger has an open gate line the gate file lacks, stop and ask the user; pre-flight asks this too (reason `gate_record_missing`).

## On resume

Pre-flight stops on a finding answered advisory (reason `gate_advisory`). For a finding left part-way (`facts`' `gate.partial`), finish the steps above before building, pushing or any rewind.

## At step 7

Once the PR is open, and never before, mark each open finding with `gate mark`, `fixed` or `user-decided`, which closes its ledger line and then its headings in the gate file.
