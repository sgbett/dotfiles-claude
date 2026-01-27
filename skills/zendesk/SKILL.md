---
name: zendesk
description: Interact with Zendesk API - read tickets, test connection, export data
allowed-tools:
  - Bash
  - Read
  - Write
---

# Zendesk Skills

Tools for interacting with the Zendesk API.

## Prerequisites

Set your Zendesk credentials as environment variables:

```bash
export ZENDESK_SUBDOMAIN=yourcompany    # Your Zendesk subdomain
export ZENDESK_EMAIL=you@example.com    # Your Zendesk email
export ZENDESK_API_TOKEN=your_token     # API token from Zendesk Admin
```

Get your API token from: Zendesk Admin > Apps and integrations > APIs > Zendesk API

## Rate Limits

PortfolioBuilder uses the **Enterprise plan** (700 requests/minute). The skills include automatic retry with exponential backoff for rate limit handling.

## Available Commands

### /zendesk:test

Test your Zendesk API connection and credentials.

```bash
/zendesk:test
```

Verifies that your credentials are valid by fetching your user profile.

**Success output:**
```
✓ Connected to Zendesk successfully!
  Subdomain: yourcompany
  User: John Smith (john@example.com)
  Role: admin
```

**On error:** Shows helpful messages for missing credentials, invalid tokens, or network issues.

### /zendesk:read <ticket_id>

Read a Zendesk ticket by ID, displaying ticket details and comments.

```bash
/zendesk:read 12345
```

Fetches the ticket and displays:
- Subject, status, priority
- Created and updated timestamps
- Requester and assignee information
- Full comment thread with authors

**Example output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Ticket #12345: Help with login issue
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Status: open     Priority: high
Created: 2026-01-20 14:30    Updated: 2026-01-24 09:15
Requester: Jane Customer <jane@example.com>
Assignee: Support Agent <support@company.com>
```

### /zendesk:macros [options]

List all Zendesk macros with their actions.

```bash
/zendesk:macros           # List all macros
/zendesk:macros --active  # Show only active macros
/zendesk:macros --json    # Output raw JSON for import processing
```

**Options:**
- `--active` - Show only active macros
- `--inactive` - Show only inactive macros
- `--json` - Output raw JSON to stdout
- `--output FILE` - Export to file (.json or .yaml/.yml)

**File Export:**
```bash
/zendesk:macros --output macros.json           # Export all to JSON
/zendesk:macros --active --output active.yaml  # Export active to YAML
```

Exported files include metadata:
```json
{
  "exported_at": "2026-01-24T10:30:00Z",
  "count": 47,
  "macros": [...]
}
```

**Example output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Zendesk Macros (47 total: 42 active, 5 inactive)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Active] #12345 - Close and thank customer
  Actions: Set status=closed, Add comment: "Thank you for..."

[Active] #12346 - Request more information
  Actions: Set status=pending, Add comment: "Could you please..."

[Inactive] #12347 - Old workflow macro
  Actions: Set status=open, Set tags: legacy
```

### /zendesk:sample-export [options]

Export tickets using the Incremental Exports API for migration validation.

```bash
/zendesk:sample-export                     # Export 100 tickets from last 30 days
/zendesk:sample-export --limit 50          # Export 50 tickets
/zendesk:sample-export --since 2026-01-01  # From specific date
```

**Options:**
- `--limit N` - Maximum tickets to export (default: 100)
- `--since DATE` - Start date in YYYY-MM-DD format (default: 30 days ago)
- `--output FILE` - Output file (default: sample-export-YYYYMMDD.json)
- `--validate` - Run data completeness validation after export
- `--resume` - Resume from last saved cursor file
- `--resume-from FILE` - Resume from specific cursor file

**Output files:**
- `sample-export-YYYYMMDD.json` - Tickets with metadata
- `sample-export-YYYYMMDD.cursor` - Cursor for resumability testing

**Example output:**
```
Exporting tickets via Incremental API...
  Start date: 2026-01-01
  Limit: 100 tickets

  Fetching page 1... 100 tickets

✓ Exported 100 tickets to sample-export-20260124.json
  Cursor saved to: sample-export-20260124.cursor
  Date range: 2026-01-01 to 2026-01-24
  Status: More tickets available (limit reached)
```

**Validation mode** (`--validate`):
Checks data completeness for migration planning:
- Fetches comments for each ticket
- Validates attachment URLs are accessible
- Reports custom fields present

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Data Completeness Validation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Tickets exported: 100

Comments:
  ✓ All 100 tickets have comments fetched
  Total comments: 847
  Avg per ticket: 8.5

Attachments:
  ✓ 156 attachments found
  ✓ All 156 URLs verified accessible

Custom Fields:
  ✓ 12 custom field IDs found with values
  Tickets with custom field data: 85 of 100

✓ No issues found - data appears complete
```

**Resume mode** (`--resume`):
Continue an interrupted export from the saved cursor:
```bash
/zendesk:sample-export --limit 50                           # Export first 50
/zendesk:sample-export --limit 50 --resume                  # Export next 50
/zendesk:sample-export --resume-from sample-export.cursor   # From specific cursor
```
