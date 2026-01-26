# Config Cleaner

Clean corrupted entries from `.claude/settings.local.json`.

## Problem

Sometimes full command text gets added to the permissions section instead of just the command pattern. This creates invalid entries like:

```json
"Bash(for f in /private/tmp/claude/-opt-claude-rcpsych-intel/tasks/*.output)"
"Bash(do if tail -20 \"$f\")"
"Bash(gh issue create --title \"fix: Add...\" --body \"$(cat <<'EOF'...)"
```

Instead of proper patterns like:

```json
"Bash(git add *)"
"Bash(gh issue create *)"
```

## Instructions

1. Read the settings file at `.claude/settings.local.json`
2. Parse the JSON and examine `permissions.allow` array
3. Identify corrupted entries using these heuristics:
   - Contains shell constructs: `do`, `done`, `fi`, `for`, `if`, `then`
   - Contains newlines or escaped quotes within the pattern
   - Contains heredoc markers: `<<`, `EOF`
   - Contains variable assignments: `VARIABLE=`
   - Length > 100 characters (proper patterns are short)
   - Contains paths like `/private/tmp/` or `/opt/`
   - Is a partial command fragment without wildcards
4. Remove corrupted entries
5. Write the cleaned JSON back to the file
6. Report what was removed

## Example Output

```
Scanning .claude/settings.local.json...

Found 8 corrupted entries:
  - Bash(for f in /private/tmp/claude/-opt-claude-rcpsych-intel/tasks/*.output)
  - Bash(do if tail -20 "$f")
  - Bash(fi)
  - Bash(done)
  - Bash(gh issue create --title "fix: Add corpus-fetcher gap detection...)
  - Bash(PARENT="I_kwDOQ_UBXs7l274x")
  - Bash(for CHILD in "I_kwDOQ_UBXs7l28bc"...)
  - Bash(do)

Removed 8 corrupted entries.
Kept 22 valid entries.

Cleaned file written to .claude/settings.local.json
```

## Valid Pattern Examples

These are valid and should be kept:
- `Bash(git add *)`
- `Bash(source *)`
- `Bash(ruby *)`
- `Bash(gh issue create *)`
- `Bash(sqlite3 *)`

## Do Not Remove

Keep entries that:
- End with `*` or `*)` (proper wildcards)
- Are short command patterns (< 50 chars typically)
- Match pattern `Bash(command *)` or `Bash(command:*)`
