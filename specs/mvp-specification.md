# PortfolioBuilder Support System - MVP Specification

**Objective**: Replace Zendesk with an in-house support system, reducing costs and enabling tighter PortfolioBuilder integration.

**Repository**: `bettison-org/portfoliobuilder-support`

## Business Case

### Cost Savings
- Zendesk: £175/seat × 3 seats × 12 months = **£6,300/year**
- In-house: ~1 additional ECS task (minimal incremental cost)

### Integration Benefits
- SSO via shared session (no separate login)
- Admin actions directly from tickets (user management, data fixes)
- Smart entity linking (identify related users, programmes, posts)
- Developer access without per-seat licensing
- Tighter GitHub workflow integration

## Support Channels

| Brand | Tenant | VOIP Number | Email |
|-------|--------|-------------|-------|
| PortfolioBuilder | default | +448009871000 | support@portfolioonline.co.uk |
| RCPsych | rcpsych | +448009871004 | support@rcpsych.portfoliobuilder.eu |
| FOM | fom | +448009871008 | support@fom.portfoliobuilder.eu |

**Note**: We control the MX records and mail server for incoming/outgoing mail.
**Note**: VOIP calls will be recorded and emailed to support addresses (no integrated telephony needed).

---

## MVP Features

### 1. Tickets

The core feature - email-based support ticket management.

#### Ticket Lifecycle (State Machine)

```
┌─────────┐    ┌────────┐    ┌─────────┐    ┌────────┐    ┌────────┐
│   New   │───▶│  Open  │───▶│ Pending │───▶│ Solved │───▶│ Closed │
└─────────┘    └────────┘    └─────────┘    └────────┘    └────────┘
                   │              │              │
                   └──────────────┴──────────────┘
                         (can reopen)
```

| Status | Colour | Description |
|--------|--------|-------------|
| New | Grey | Incoming, unassigned |
| Open | Red | Being worked on |
| Pending | Blue | Awaiting customer response |
| Solved | Green | Resolution provided |
| Closed | Black | Archived |

#### Ticket Attributes

| Field | Type | Notes |
|-------|------|-------|
| id | integer | Primary key |
| external_id | string | Zendesk ID for migration xref |
| subject | string | Email subject |
| status | enum | new/open/pending/solved/closed |
| priority | enum | low/normal/high/urgent |
| tenant | string | default/rcpsych/fom |
| requester_id | references | User who raised ticket |
| assignee_id | references | Support agent assigned |
| tags | array | For categorisation |
| created_at | datetime | |
| updated_at | datetime | |

#### Ticket Events (Comments/Replies)

| Field | Type | Notes |
|-------|------|-------|
| id | integer | Primary key |
| ticket_id | references | Parent ticket |
| author_id | references | User who created event |
| body | text | Content (markdown) |
| public | boolean | true=reply (sent to customer), false=internal note |
| created_at | datetime | |

**Behaviour**:
- **Reply** (public=true): Sends email to requester, returns to ticket index (unless "stay on ticket" checked)
- **Comment** (public=false): No email sent, stays on ticket (unless "leave ticket" checked)

#### Views (Ticket Lists)

Default homepage shows filterable ticket list (not a dashboard).

**Standard Views**:
- Unassigned tickets
- My open tickets
- All unsolved tickets
- Recently updated
- Pending tickets
- Solved tickets

**Features**:
- Sortable by column headers (default: most recently updated)
- Pagination
- Bulk actions: mark as spam, mark as solved, merge

#### Ticket Actions

| Action | Description |
|--------|-------------|
| Reply | Send public response (emails customer) |
| Comment | Add internal note (not visible to customer) |
| Assign | Assign to agent |
| Change status | Update ticket status |
| Add tags | Categorise ticket |
| Merge | Combine duplicate tickets |
| Mark as spam | Delete/hide ticket |
| Link to GitHub | Create/link GitHub issue |

### 2. Guides (Help Centre)

Markdown-based documentation with tenant-specific content.

#### Guide Attributes

| Field | Type | Notes |
|-------|------|-------|
| id | integer | Primary key |
| slug | string | URL-friendly identifier |
| title | string | |
| body | text | Markdown content |
| category_id | references | Parent category |
| position | integer | Sort order |
| published | boolean | |
| tenant_visibility | array | Which tenants can see this |
| created_at | datetime | |
| updated_at | datetime | |

#### Features
- Markdown editing with live preview
- Conditional content based on tenant (preprocessor directives)
- Single master guide with tenant-specific overrides
- Categories for organisation

**Example conditional content**:
```markdown
## Getting Started

Welcome to PortfolioBuilder!

{% if tenant == 'rcpsych' %}
Your RCPsych portfolio is pre-configured with the required competencies.
{% elsif tenant == 'fom' %}
Your FOM portfolio includes occupational medicine requirements.
{% endif %}
```

### 3. Macros (Canned Responses)

Pre-defined actions to speed up common responses.

#### Macro Attributes

| Field | Type | Notes |
|-------|------|-------|
| id | integer | Primary key |
| name | string | Display name |
| body | text | Optional: text to insert |
| status | enum | Optional: status to set |
| tags | array | Optional: tags to add |
| position | integer | Sort order in dropdown |

**Constraints**: At least one of body/status/tags must be defined.

**Behaviour**:
- Select macro from dropdown, click "Apply"
- Appends body to comment/reply box (if defined)
- Pre-sets status dropdown (if defined)
- Adds tags (if defined, no duplicates)
- User can amend before submitting
- Can apply multiple macros (additive)

### 4. GitHub Integration

Link support tickets to GitHub issues for developer handoff.

#### Features
- Create GitHub issue from ticket
- Link existing issue to ticket
- Sync issue status back to ticket
- Show linked issues in ticket view

---

## User Requirements Summary

Based on team feedback:

### Essential
- Status workflow with Zendesk colour scheme
- Views page as homepage (not dashboard)
- Sortable columns, default by most recently updated
- Reply → email + return to index (with "stay" checkbox)
- Comment → no email + stay on ticket (with "leave" checkbox)
- Internal notes not visible to requester
- Bulk actions (spam, solved)
- Merge tickets
- Pre-set replies (macros)

### Not Needed (Zendesk Overkill)
- Browser tabs functionality (use native tabs)
- Full macro/trigger automation
- WYSIWYG editing (markdown is fine)
- Separate guides per brand (use conditional content)
- Integrated VOIP (email recordings instead)
- "Who else is viewing" feature (unreliable anyway)

---

## Technical Architecture

### Stack
- Rails 8.1, Ruby 3.4
- PostgreSQL (shared with main app)
- Redis (shared sessions)
- Puma on port 8081
- Tailwind CSS

### Multi-Tenancy

Tenant detection via `domain_config` helper:
- `beta.*` → `:beta`
- `training.rcpsych.ac.uk` → `:rcpsych`
- `portfolioonline.co.uk` → `:rcpsych`
- Subdomain → `:subdomain`
- Default → `:default`

### Session Sharing

Shared Redis session with main PortfolioBuilder app:
- Cookie key: `_session_id`
- Redis: `redis://#{REDIS_HOST}/0/session`
- Expiry: 24 hours

### Infrastructure

**Development**: Docker Compose service in main portfoliobuilder repo
**Production**: ECS Fargate task (single instance sufficient)

### Nginx Routing

```nginx
location ~ ^/(support|help) {
  proxy_pass http://support:8081;
}
```

---

## UI Components (Tailwind Plus)

| Component | Use Case |
|-----------|----------|
| Multi-Column Layout (narrow sidebar) | Default page layout |
| Tables (stacked on mobile) | Ticket list views |
| Stacked Forms | Ticket detail/reply |
| Sidebar Navigation | Views menu |
| Pagination (card footer) | Ticket lists |
| Breadcrumbs (contained) | Navigation path |
| List with dividers | Ticket event timeline |

---

## Data Migration

### Tickets
1. Route new emails to both systems (disable autoreply on new system)
2. Respond from new system, fallback to Zendesk if issues
3. Work existing open tickets in Zendesk until cleared
4. Migrate solved/closed tickets via API dump
5. Migrate inactive (>1 month) in-flight tickets
6. Retain Zendesk IDs for cross-reference

### Guides
1. Export existing guides from Zendesk
2. Convert to Markdown
3. Resolve brand differences:
   - Minor: assume identity, merge
   - Major: conditional content or separate articles
4. Create consolidated master guide
5. Add tenant-specific conditional sections

### API Reference
- Zendesk REST API: https://developer.zendesk.com/api-reference/

---

## Phases

### Phase 0: Infrastructure Integration ✓
- [x] Skeleton Rails 8 app
- [x] Docker Compose integration
- [x] Nginx routing (`/support`, `/help`)
- [x] Session sharing validation
- [x] GitHub repository setup
- [x] CI pipeline

### Phase 1: MVP Development
- [ ] Ticket model and CRUD
- [ ] Ticket event model (comments/replies)
- [ ] Email ingestion (receive)
- [ ] Email sending (replies)
- [ ] Views/filters
- [ ] Bulk actions
- [ ] Macros
- [ ] Guide model and CRUD
- [ ] Guide categories
- [ ] Markdown rendering
- [ ] Conditional content
- [ ] GitHub issue linking

### Phase 2: Deployment & Testing
- [ ] ECS task definition
- [ ] Production deployment
- [ ] Parallel running with Zendesk
- [ ] Data migration
- [ ] Zendesk sunset

---

## Future Enhancements

- **Entity Linking**: Detect and link PortfolioBuilder entities (users, programmes, posts) in tickets
- **Quick Access Panel**: Split view showing related entities
- **Triggers**: IFTTT-style automation (when X happens, do Y)
- **Screenshot Integration**: Auto-capture screenshots from feature tests for guides
- **End-User Ticket View**: Allow users to see their own tickets
- **Programme Admin View**: Role-based collaboration features
