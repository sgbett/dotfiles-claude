---
name: read-email
description: Reads emails from Gmail account. Use when the user asks to "look at emails", "check emails from [sender]", "read recent emails", or "/read-email". Fetches emails with full body content for analysis.
allowed-tools: Bash,Read
---

# Read Email

Fetches and displays emails from Gmail using OAuth credentials.

## Prerequisites

- `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` environment variables must be set
- OAuth token file at `~/.claude/gmail_token.yaml` (or custom path via `GMAIL_TOKEN_PATH`)

## Usage

When the user requests to read emails, extract:
1. **Sender** - Email address to filter by (e.g., `support@example.com`)
2. **Limit** - Number of emails (default: 10)
3. **Query** - Optional Gmail search query for advanced filtering

## Process

### 1. Parse User Request

Extract the sender email address or search query from the user's request:
- "look at recent emails from support@example.com" → `--from support@example.com`
- "check my last 5 emails from acme corp" → `--from notifications@acme.com --limit 5`
- "find emails about invoice" → `--query "subject:invoice"`

### 2. Run the Gmail Reader

```bash
source ~/.rvm/scripts/rvm && rvm use ruby-3.4.2 && ruby ~/.claude/skills/read-email/bin/gmail-reader.rb --from <sender> --limit <n>
```

Options:
- `-f, --from SENDER` - Filter by sender email address
- `-q, --query QUERY` - Gmail search query (overrides --from)
- `-l, --limit N` - Maximum emails to return (default: 10)

### 3. Present Results

Parse the JSON output and present emails in a readable format:

```
## Email from [sender]
**Subject**: [subject]
**Date**: [date]

[body content]

---
```

For each email:
- Show sender, subject, and date prominently
- Display full body content
- Summarise key points if the email is lengthy
- Highlight any action items or important information

### 4. Offer Follow-up Actions

After presenting emails, suggest relevant actions:
- "Would you like me to summarise these emails?"
- "Should I draft a reply to any of these?"
- "Want to search for related emails?"

## Examples

**User**: "look at recent emails from support@example.com"
```bash
source ~/.rvm/scripts/rvm && rvm use ruby-3.4.2 && ruby ~/.claude/skills/read-email/bin/gmail-reader.rb --from support@example.com --limit 10
```

**User**: "check my last 3 emails from Acme Corp"
```bash
source ~/.rvm/scripts/rvm && rvm use ruby-3.4.2 && ruby ~/.claude/skills/read-email/bin/gmail-reader.rb --from notifications@acme.com --limit 3
```

**User**: "find emails about the project proposal"
```bash
source ~/.rvm/scripts/rvm && rvm use ruby-3.4.2 && ruby ~/.claude/skills/read-email/bin/gmail-reader.rb --query "subject:project proposal" --limit 10
```

## Error Handling

- **Missing environment variables**: Ensure `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set
- **Authorization required**: OAuth token file missing - run the OAuth flow to generate `~/.claude/gmail_token.yaml`
- **No emails found**: Report that no matching emails were found
- **Network error**: Suggest checking internet connection and retrying

## Output Format

The script returns JSON:
```json
[
  {
    "id": "message-id",
    "from": "sender@example.com",
    "to": "recipient@example.com",
    "subject": "Email subject",
    "date": "Fri, 10 Jan 2025 10:30:00 +0000",
    "body": "Full plain-text email body..."
  }
]
```

## Notes

- Prefers plain-text email body over HTML
- Falls back to HTML with tags stripped if no plain-text available
- Uses read-only Gmail scope (cannot send or modify emails)
- First run may be slow due to gem installation (bundler/inline)
- Token path defaults to `~/.claude/gmail_token.yaml`, override with `GMAIL_TOKEN_PATH` env var
