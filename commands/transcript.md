---
description: Exports the current session's conversation to a human-readable markdown file. Use when the user asks to "export transcript", "save conversation", "generate transcript", or "/transcript". Creates a markdown file in ~/.claude/transcripts/ with timestamped filename.
---

# Export Session Transcript

Exports the current Claude Code session to a human-readable markdown file in `~/.claude/transcripts/`.

## Process

### 1. Identify Current Session

Find the current session's JSONL file:

1. Determine the project path (current working directory)
2. Convert to Claude's project path format: `~/.claude/projects/<escaped-path>/`
   - Replace `/` with `-` and remove leading `-`
   - Example: `/opt/ruby/portfoliobuilder` → `-opt-ruby-portfoliobuilder`
3. Find the most recently modified `.jsonl` file (excluding `agent-*.jsonl` subagent files)

```bash
# Find current session file
PROJECT_PATH=$(pwd | sed 's|/|-|g')
ls -t ~/.claude/projects/${PROJECT_PATH}/*.jsonl 2>/dev/null | grep -v 'agent-' | head -1
```

### 2. Extract Session Metadata

From the JSONL file, extract:
- **Session ID**: from any message's `sessionId` field
- **Session name**: Check `~/.claude/projects/<project>/.session-name` if it exists, otherwise derive from conversation topic
- **Start time**: from the first message's `timestamp`
- **Git branch**: from any message's `gitBranch` field

### 3. Parse Messages

Read the JSONL file and parse each line. Extract messages where `type` is `user` or `assistant`.

For each message:
- **User messages**: Extract text from `message.content` (may be string or array with `text` field)
- **Assistant messages**: Extract text from `message.content` (may be string or array of content blocks)
- **Tool uses**: Skip entirely (do not include `[Tool: ...]` lines)
- **Tool results**: Skip entirely

Skip:
- System messages
- Internal metadata-only entries
- Tool use and tool result blocks
- Very long tool outputs

### 3a. Post-Processing

After parsing, apply these transformations:
1. **Consolidate consecutive assistant messages**: Merge multiple consecutive `### Assistant` sections into one
2. **Strip backticks**: Remove all backtick characters from the original content
3. **Strip tool lines**: Remove any remaining `[Tool: ...]` lines

### 4. Generate Descriptive Name (Semantic Analysis)

Determine the transcript filename's descriptive portion using semantic analysis of the **entire conversation**:

1. **If custom name provided**: Use the argument passed to `/transcript my-name`
2. **Otherwise, derive from content** using frequency analysis:
   - Analyse ALL messages (user and assistant)
   - Extract meaningful words from URLs before removing them
   - Clean text: remove URLs, file paths, code blocks, markdown formatting
   - Count word frequencies across entire conversation
   - Find significant bigrams (two-word phrases appearing 2+ times)
   - Prefer bigrams containing high-frequency words
   - Generate a kebab-case slug (3-4 terms max)
   - Examples: `topic-derivation-clawdbot-skill`, `rails-upgrade-authentication`, `api-refactor-endpoints`

**Semantic analysis pseudo-code:**
```ruby
# Combine all message content
all_text = merged.map { |m| m[:content] }.join(" ")

# Extract meaningful parts from URLs (with frequency boost)
url_words = all_text.scan(%r{https?://[^\s]+}).flat_map do |url|
  url.sub(%r{https?://}, '').split(%r{[/.\-]}).reject do |part|
    part.match?(/^(www|com|org|io|github|net|co|uk|\d+)$/i) || part.length < 3
  end
end

# Clean text: remove URLs, paths, code blocks, markdown
text = all_text
  .gsub(%r{https?://\S+}, ' ')           # URLs
  .gsub(%r{/[\w/.\-]+}, ' ')             # File paths
  .gsub(/```[\s\S]*?```/, ' ')           # Fenced code blocks
  .gsub(/`[^`]+`/, ' ')                  # Inline code

# Count word frequencies (excluding comprehensive stop words)
word_freq = Hash.new(0)
words.each { |w| word_freq[w] += 1 unless stop_word?(w) }
url_words.each { |w| word_freq[w.downcase] += 3 }  # Boost URL terms

# Find significant bigrams
bigram_freq = Hash.new(0)
clean_words.each_cons(2) { |w1, w2| bigram_freq["#{w1}-#{w2}"] += 1 }

# Build topic: prefer bigrams with top words, fill with single words
top_words = word_freq.sort_by { |_, v| -v }.first(20).map(&:first)
top_bigrams = bigram_freq.select { |_, v| v >= 2 }.sort_by { |_, v| -v }

topic_parts = []
# Add bigrams containing top-5 words
top_bigrams.each do |bigram, _|
  if bigram.split('-').any? { |p| top_words.first(5).include?(p) }
    topic_parts << bigram
    break if topic_parts.length >= 2
  end
end
# Fill with top single words not already used
top_words.each { |w| topic_parts << w unless used?(w) }

topic = topic_parts.first(4).join('-')
```

### 5. Format as Markdown

Generate markdown with this structure:
- **User messages**: Prefix with `\>` (escaped greater-than, renders as literal `>`)
- **Assistant messages**: Wrap in triple backticks (code block)
- **No section headers**: Do not include `### User` or `### Assistant` headings

```markdown
# Session Transcript

**Date**: YYYY-MM-DD HH:MM
**Project**: <project-path>
**Branch**: <git-branch>
**Session ID**: <session-id>

---

## Conversation

\> user message content here

` ` `
assistant message content here
` ` `

\> next user message

` ` `
assistant response here
` ` `

---

*Exported from Claude Code session on YYYY-MM-DD at HH:MM*
```

### 6. Write Output File

1. Create `~/.claude/transcripts/` directory if it doesn't exist
2. Generate filename: `YYYYMMDD_<descriptive-name>.md`
   - Use current date (overwrites if run again same day)
   - Use derived or explicit session name for descriptive portion
3. Write the markdown file

### 7. Report Success

Output:
```
Transcript exported to: ~/.claude/transcripts/YYYYMMDD_descriptive-name.md

Summary:
- Messages: <count>
- Duration: <first to last message time>
- Topic: <derived topic>
```

## Formatting Guidelines

### User Messages
- Prefix with `\>` (escaped, renders as literal `>`)
- Display content as-is after the prefix
- For multi-part messages, join with newlines

### Assistant Messages
- Wrap entire content in triple backticks (code block)
- Strip all backticks from original content before wrapping
- Consolidate consecutive assistant messages into one block
- Do not include tool use references

### Tool Uses and Results
- Omit entirely from output

### Thinking Blocks
- Omit by default (internal reasoning)
- Could add `--include-thinking` flag in future

## Example Output

```markdown
# Session Transcript

**Date**: 2026-01-13 17:55
**Project**: /opt/ruby/portfoliobuilder
**Branch**: feature/rails-upgrade-spike
**Session ID**: 4f7ff568-46af-44ac-88a8-b23b7bc521e4

---

## Conversation

\> what does this do: https://github.com/clawdbot/clawdbot

` ` `
Clawdbot is a personal AI assistant you run on your own devices. Key features:

- Multi-channel inbox — connects to WhatsApp, Telegram, Slack, Discord...
` ` `

\> does it provide an ability to generate a chat transcript?

` ` `
Based on the README, yes — Clawdbot has transcript capabilities:

sessions_history — fetches transcript logs for a session...
` ` `

---

*Exported from Claude Code session on 2026-01-13 at 18:00*
```

## Error Handling

- **No session found**: "Could not identify current session. Are you in a Claude Code project?"
- **Empty session**: "Session has no messages to export."
- **Write permission error**: Suggest alternative location or show content to stdout

## Optional Arguments

The command can accept optional arguments:

- `/transcript` - Export with auto-generated name
- `/transcript my-custom-name` - Export with specified name
- `/transcript --stdout` - Output to console instead of file (future)
- `/transcript --full` - Include full tool outputs (future)

## Related

- Session files are stored in `~/.claude/projects/<project>/<session-id>.jsonl`
- File history (edit snapshots) in `~/.claude/file-history/<session-id>/`
- Command history in `~/.claude/history.jsonl`
