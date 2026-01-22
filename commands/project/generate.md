# Generate Project from Plan

Generates a complete GitHub Project with issue hierarchy from a plan file. Creates HLR issue (if missing), phase issues, task issues, and links them as sub-issues with proper project field assignments.

**Task:** Generate GitHub Project from plan: $ARGUMENTS

## Step 1: Locate and Parse Plan File

**Find the plan file:**

```bash
# If argument provided, use it
if [ -n "$ARGUMENTS" ]; then
    PLAN_FILE="$ARGUMENTS"
else
    # Find most recent plan in current project
    PLAN_FILE=$(ls -t .claude/plans/*.md 2>/dev/null | head -1)
fi

# Verify file exists
cat "$PLAN_FILE"
```

**Parse the plan to extract:**

1. **Title**: First `# Plan: [Title]` or `# [Title]` heading
2. **Summary**: Content under `## Summary` section
3. **Existing issue number**: Look for `**Issue**: #1234` in Context section
4. **Phases**: All `## Phase N: [Title]` headings with their goals
5. **Tasks**: All `### N.M [Title]` headings under phases

**Parsing patterns:**
```
Title:    ^# Plan:\s*(.+)$  OR  ^# (.+)$
Issue:    \*\*Issue\*\*:?\s*#?(\d+)
Phase:    ^## Phase (\d+):?\s*(.+)$
Goal:     ^\*\*Goal:?\*\*:?\s*(.+)$
Task:     ^### (\d+)\.(\d+)\s+(.+)$
```

**Skip tasks that reference existing issues:**

If a task title contains `(#1234)` or similar, check if that issue is already in a GitHub Project:

```bash
# Extract issue number from task title
EXISTING_ISSUE=$(echo "$TASK_TITLE" | grep -oE '#[0-9]+' | grep -oE '[0-9]+')

if [ -n "$EXISTING_ISSUE" ]; then
    # Check if issue is in any project
    IN_PROJECT=$(gh api graphql -f query='
        query($owner: String!, $repo: String!, $number: Int!) {
            repository(owner: $owner, name: $repo) {
                issue(number: $number) {
                    projectItems(first: 1) {
                        totalCount
                    }
                }
            }
        }
    ' -f owner="$OWNER" -f repo="$REPO" -F number="$EXISTING_ISSUE" \
        --jq '.data.repository.issue.projectItems.totalCount')

    if [ "$IN_PROJECT" -gt 0 ]; then
        echo "Skipping task $TASK_NUM - references existing issue #$EXISTING_ISSUE (already in a project)"
        continue
    fi
fi
```

This prevents creating duplicate tracking for work that's already managed elsewhere.

## Step 2: Determine Repository Context

**Get repository information:**

```bash
# Get owner and repo from git remote
REMOTE_URL=$(git remote get-url upstream 2>/dev/null || git remote get-url origin)
OWNER=$(echo "$REMOTE_URL" | sed -n 's/.*github.com[:/]\([^/]*\)\/.*/\1/p')
REPO=$(echo "$REMOTE_URL" | sed -n 's/.*github.com[:/][^/]*\/\([^.]*\).*/\1/p')

echo "Repository: $OWNER/$REPO"
```

## Step 3: Create or Verify HLR Issue

**If no issue number found in plan:**

```bash
# Create HLR issue
HLR_BODY=$(cat <<'EOF'
## Summary

{summary_from_plan}

## Plan

See `{plan_file_path}` for detailed implementation plan.

## Task Breakdown

_This section will be populated with phase and task issues._
EOF
)

HLR_URL=$(gh issue create \
    --repo "$OWNER/$REPO" \
    --title "{plan_title}" \
    --label "project:hlr" \
    --body "$HLR_BODY")

HLR_NUMBER=$(echo "$HLR_URL" | grep -oE '[0-9]+$')
echo "Created HLR issue: #$HLR_NUMBER"

# Update plan file with issue number
# Add to Context section: **Issue**: #$HLR_NUMBER
```

**If issue number found:**

```bash
# Verify it exists
gh api repos/$OWNER/$REPO/issues/$HLR_NUMBER --jq '.number' || {
    echo "Issue #$HLR_NUMBER not found"
    exit 1
}
```

## Step 4: Create Labels (Idempotent)

```bash
# Create labels if they don't exist
gh label create "project:hlr" --description "High Level Requirement" --color "fbefff" --repo "$OWNER/$REPO" 2>/dev/null || true
gh label create "project:phase" --description "Project phase" --color "ddf4ff" --repo "$OWNER/$REPO" 2>/dev/null || true
gh label create "project:task" --description "Project task" --color "f6f8fa" --repo "$OWNER/$REPO" 2>/dev/null || true
```

## Step 5: Create GitHub Project from Template

**Copy from template project:**

The template project (bettison-org Project #20) contains pre-configured views (Phases, Tasks, List) and base Phase field options (Project, Progress).

```bash
PROJECT_TITLE="{plan_title}"
TEMPLATE_PROJECT=20

# Copy from template
PROJECT_JSON=$(gh project copy "$TEMPLATE_PROJECT" \
    --source-owner "$OWNER" \
    --target-owner "$OWNER" \
    --title "$PROJECT_TITLE" \
    --format json)

PROJECT_NUMBER=$(echo "$PROJECT_JSON" | jq -r '.number')
PROJECT_URL=$(echo "$PROJECT_JSON" | jq -r '.url')
echo "Created project from template: $PROJECT_URL"
```

**Add project-specific Phase options:**

The template has "Project" and "Progress" options. Add phase-specific options (Phase 1, Phase 2, etc.) using GraphQL mutation:

```bash
# Get the project's node ID and Phase field ID
PROJECT_DATA=$(gh api graphql -f query='
    query($owner: String!, $number: Int!) {
        organization(login: $owner) {
            projectV2(number: $number) {
                id
                fields(first: 20) {
                    nodes {
                        ... on ProjectV2SingleSelectField {
                            id
                            name
                        }
                    }
                }
            }
        }
    }
' -f owner="$OWNER" -F number="$PROJECT_NUMBER")

PROJECT_ID=$(echo "$PROJECT_DATA" | jq -r '.data.organization.projectV2.id')
PHASE_FIELD_ID=$(echo "$PROJECT_DATA" | jq -r '.data.organization.projectV2.fields.nodes[] | select(.name=="Phase") | .id')

# Add each phase option
for phase_num in "${PHASE_NUMBERS[@]}"; do
    OPTION_NAME="Phase $phase_num"
    gh api graphql -f query='
        mutation($projectId: ID!, $fieldId: ID!, $name: String!) {
            updateProjectV2Field(input: {
                projectId: $projectId
                fieldId: $fieldId
                singleSelectField: {
                    options: { name: $name }
                }
            }) {
                field {
                    ... on ProjectV2SingleSelectField {
                        options { name }
                    }
                }
            }
        }
    ' -f projectId="$PROJECT_ID" -f fieldId="$PHASE_FIELD_ID" -f name="$OPTION_NAME"
done
```

**Get field and option IDs for later use:**

```bash
FIELDS_JSON=$(gh project field-list "$PROJECT_NUMBER" --owner "$OWNER" --format json)

PHASE_FIELD_ID=$(echo "$FIELDS_JSON" | jq -r '.fields[] | select(.name=="Phase") | .id')

# Extract option IDs for fixed options
PROJECT_OPTION_ID=$(echo "$FIELDS_JSON" | jq -r '.fields[] | select(.name=="Phase") | .options[] | select(.name=="Project") | .id')
PROGRESS_OPTION_ID=$(echo "$FIELDS_JSON" | jq -r '.fields[] | select(.name=="Phase") | .options[] | select(.name=="Progress") | .id')

# Phase option IDs use short names: "Phase 1", "Phase 2", etc.
# Retrieved dynamically when setting task field values
```

## Step 6: Add HLR Issue to Project

```bash
# Add HLR to project
ITEM_ID=$(gh project item-add "$PROJECT_NUMBER" \
    --owner "$OWNER" \
    --url "https://github.com/$OWNER/$REPO/issues/$HLR_NUMBER" \
    --format json | jq -r '.id')

# Set Phase field to "Project"
gh project item-edit \
    --project-id "$PROJECT_NUMBER" \
    --id "$ITEM_ID" \
    --field-id "$PHASE_FIELD_ID" \
    --single-select-option-id "$PROJECT_OPTION_ID"
```

## Step 7: Create Phase Issues

**For each phase extracted from the plan:**

```bash
for phase in "${PHASES[@]}"; do
    PHASE_NUM="${phase[num]}"
    PHASE_TITLE="${phase[title]}"
    PHASE_GOAL="${phase[goal]}"
    PHASE_FULL_NAME="Phase $PHASE_NUM: $PHASE_TITLE"

    # Create phase issue body
    PHASE_BODY=$(cat <<EOF
## Parent Issue

Part of #$HLR_NUMBER

## Goal

$PHASE_GOAL

## Tasks

_Task issues will be linked as sub-issues below._

## Completion Gate

- [ ] All tasks complete
- [ ] Phase reviewed and approved
EOF
)

    # Create the issue
    PHASE_URL=$(gh issue create \
        --repo "$OWNER/$REPO" \
        --title "[Phase $PHASE_NUM] $PHASE_TITLE" \
        --label "project:phase" \
        --body "$PHASE_BODY")

    PHASE_ISSUE_NUM=$(echo "$PHASE_URL" | grep -oE '[0-9]+$')

    # Get database ID for sub-issue linking
    PHASE_DB_ID=$(gh api repos/$OWNER/$REPO/issues/$PHASE_ISSUE_NUM --jq '.id')

    # Link as sub-issue of HLR
    gh api repos/$OWNER/$REPO/issues/$HLR_NUMBER/sub_issues \
        -X POST \
        -F sub_issue_id=$PHASE_DB_ID

    # Add to project with Phase="Progress"
    ITEM_ID=$(gh project item-add "$PROJECT_NUMBER" \
        --owner "$OWNER" \
        --url "$PHASE_URL" \
        --format json | jq -r '.id')

    gh project item-edit \
        --project-id "$PROJECT_NUMBER" \
        --id "$ITEM_ID" \
        --field-id "$PHASE_FIELD_ID" \
        --single-select-option-id "$PROGRESS_OPTION_ID"

    echo "Created phase: #$PHASE_ISSUE_NUM - [Phase $PHASE_NUM] $PHASE_TITLE"

    # Store for task creation
    PHASE_ISSUES[$PHASE_NUM]=$PHASE_ISSUE_NUM
done
```

## Step 8: Create Task Issues

**For each task under each phase:**

```bash
for task in "${TASKS[@]}"; do
    PHASE_NUM="${task[phase]}"
    TASK_NUM="${task[num]}"
    TASK_TITLE="${task[title]}"
    TASK_DESCRIPTION="${task[description]}"
    PARENT_PHASE_ISSUE="${PHASE_ISSUES[$PHASE_NUM]}"
    PHASE_FULL_NAME="Phase $PHASE_NUM: ${PHASE_TITLES[$PHASE_NUM]}"

    # Determine task area from title or content
    # Look for keywords: Backend, Frontend, Testing, Infrastructure, Documentation
    AREA="Implementation"  # Default
    if echo "$TASK_TITLE" | grep -qi "test"; then AREA="Testing"; fi
    if echo "$TASK_TITLE" | grep -qi "backend\|api\|database"; then AREA="Backend"; fi
    if echo "$TASK_TITLE" | grep -qi "frontend\|ui\|component"; then AREA="Frontend"; fi
    if echo "$TASK_TITLE" | grep -qi "doc"; then AREA="Documentation"; fi
    if echo "$TASK_TITLE" | grep -qi "infra\|deploy"; then AREA="Infrastructure"; fi

    # Create task issue body
    TASK_BODY=$(cat <<EOF
# Task $PHASE_NUM.$TASK_NUM: $TASK_TITLE

**Parent Issue:** #$PARENT_PHASE_ISSUE (Part of Phase $PHASE_NUM)
**Task Number:** $PHASE_NUM.$TASK_NUM
**Area:** $AREA

## Description

$TASK_DESCRIPTION

## Acceptance Criteria

- [ ] Implementation complete
- [ ] Tests written and passing
- [ ] Code reviewed

## Definition of Done

- [ ] All acceptance criteria met
- [ ] PR merged to working master
EOF
)

    # Create the issue
    TASK_URL=$(gh issue create \
        --repo "$OWNER/$REPO" \
        --title "[Task $PHASE_NUM.$TASK_NUM] $AREA: $TASK_TITLE" \
        --label "project:task" \
        --body "$TASK_BODY")

    TASK_ISSUE_NUM=$(echo "$TASK_URL" | grep -oE '[0-9]+$')

    # Get database ID for sub-issue linking
    TASK_DB_ID=$(gh api repos/$OWNER/$REPO/issues/$TASK_ISSUE_NUM --jq '.id')

    # Link as sub-issue of parent phase
    gh api repos/$OWNER/$REPO/issues/$PARENT_PHASE_ISSUE/sub_issues \
        -X POST \
        -F sub_issue_id=$TASK_DB_ID

    # Get option ID for this phase number (e.g., "Phase 1")
    PHASE_SHORT_NAME="Phase $PHASE_NUM"
    PHASE_OPTION_ID=$(echo "$FIELDS_JSON" | jq -r --arg name "$PHASE_SHORT_NAME" '.fields[] | select(.name=="Phase") | .options[] | select(.name==$name) | .id')

    # Add to project with Phase=parent phase name
    ITEM_ID=$(gh project item-add "$PROJECT_NUMBER" \
        --owner "$OWNER" \
        --url "$TASK_URL" \
        --format json | jq -r '.id')

    gh project item-edit \
        --project-id "$PROJECT_NUMBER" \
        --id "$ITEM_ID" \
        --field-id "$PHASE_FIELD_ID" \
        --single-select-option-id "$PHASE_OPTION_ID"

    echo "Created task: #$TASK_ISSUE_NUM - [Task $PHASE_NUM.$TASK_NUM] $TASK_TITLE"

    # Store for plan update
    TASK_ISSUES["$PHASE_NUM.$TASK_NUM"]=$TASK_ISSUE_NUM
done
```

## Step 9: Update Plan File

**Add issue numbers to phase and task headers:**

```bash
# Update phase headers: "## Phase 0: Security Fixes" → "## Phase 0: Security Fixes (#1288)"
for phase_num in "${!PHASE_ISSUES[@]}"; do
    issue_num="${PHASE_ISSUES[$phase_num]}"
    # Use sed or similar to update the plan file
done

# Update task headers: "### 0.1 Fix XSS" → "### 0.1 Fix XSS (#1269)"
for task_key in "${!TASK_ISSUES[@]}"; do
    issue_num="${TASK_ISSUES[$task_key]}"
    # Use sed or similar to update the plan file
done
```

**Add Issue Hierarchy section at the end of the plan:**

```markdown
---

## Issue Hierarchy

- #{hlr_number} [HLR] {plan_title}
  - #{phase_0_number} [Phase 0] {phase_0_title}
    - #{task_0_1_number} [Task 0.1] {task_0_1_title}
    - #{task_0_2_number} [Task 0.2] {task_0_2_title}
  - #{phase_1_number} [Phase 1] {phase_1_title}
    - #{task_1_1_number} [Task 1.1] {task_1_1_title}
    ...
```

## Step 10: Update HLR Issue with Task Breakdown

**Add task breakdown checklist to HLR issue:**

```bash
BREAKDOWN=$(cat <<EOF
## Task Breakdown

This issue has been broken down into the following phases and tasks:

### Phase 0: $PHASE_0_TITLE
- [ ] #$PHASE_0_ISSUE - [Phase 0] $PHASE_0_TITLE
  - [ ] #$TASK_0_1_ISSUE - [Task 0.1] $TASK_0_1_TITLE
  - [ ] #$TASK_0_2_ISSUE - [Task 0.2] $TASK_0_2_TITLE

### Phase 1: $PHASE_1_TITLE
...

**Total Phases:** {phase_count}
**Total Tasks:** {task_count}
**GitHub Project:** {project_url}
EOF
)

# Update the HLR issue body with the breakdown
gh issue edit "$HLR_NUMBER" --repo "$OWNER/$REPO" --body "$UPDATED_BODY"
```

## Step 11: Report Summary

```
Project generated successfully!

GitHub Project: {project_url}

HLR Issue: #{hlr_number} - {plan_title}

Phases Created:
  - #{phase_0_number} [Phase 0] {phase_0_title}
  - #{phase_1_number} [Phase 1] {phase_1_title}
  ...

Tasks Created:
  - #{task_0_1_number} [Task 0.1] {task_0_1_title}
  - #{task_0_2_number} [Task 0.2] {task_0_2_title}
  - #{task_1_1_number} [Task 1.1] {task_1_1_title}
  ...

Plan file updated: {plan_file_path}
  - Issue numbers added to phase/task headers
  - Issue Hierarchy section added

Next Steps:
  1. Review the GitHub Project: {project_url}
  2. Create a worktree for this project: /project:worktree #{hlr_number}
  3. Start working on Phase 0 tasks
```

## Idempotency

**Handle re-runs gracefully:**

1. **HLR exists in plan**: Use existing issue, don't recreate
2. **Labels exist**: Skip silently (`2>/dev/null || true`)
3. **Project with same name exists**: Warn user and ask whether to use existing or create new
4. **Phase/Task issues exist**: Check by title pattern before creating
   ```bash
   EXISTING=$(gh issue list --repo "$OWNER/$REPO" --search "in:title [Phase 0]" --label "project:phase" --json number,title)
   ```
5. **Plan already has issue numbers**: Parse and use them, only create missing issues

**Template Project:**

The command copies from template Project #20 (bettison-org). This template contains:
- Pre-configured views: Phases, Tasks, List
- Base Phase field options: Project, Progress
- Standard Status field: Todo, In Progress, Done, Pending

If the template is deleted or modified, create a new one with the same structure.

## Error Handling

| Error | Action |
|-------|--------|
| Plan file not found | Exit with clear error message |
| Invalid plan format | Show parsing error with expected format |
| API rate limit | Warn and suggest waiting; allow retry |
| Issue creation fails | Log error, continue with remaining; report failures at end |
| Project creation fails | Exit with error; some issues may have been created |
| Sub-issue linking fails | Warn but continue (issues exist, just unlinked) |
| Plan file update fails | Warn but report success (GitHub resources created) |

## Example Output

```
User: /project:generate .claude/plans/20260117-bootstrap-helper-abstraction.md

Parsing plan file...
  Title: Bootstrap Helper Abstraction
  Phases found: 4
  Tasks found: 12
  Existing issue: #1252

Creating GitHub Project from template #20...
  Project created: https://github.com/orgs/bettison-org/projects/21
  Views copied: Phases, Tasks, List
  Adding Phase options: Phase 0, Phase 1, Phase 2, Phase 3

Creating phase issues...
  Created: #1288 - [Phase 0] Security Fixes
  Created: #1289 - [Phase 1] Create Helpers
  Created: #1290 - [Phase 2] Integration
  Created: #1291 - [Phase 3] Cleanup

Creating task issues...
  Created: #1292 - [Task 0.1] Security: Fix XSS vulnerabilities
  Created: #1293 - [Task 0.2] Testing: Create unit test foundation
  ...

Updating plan file...
  Added issue numbers to headers
  Added Issue Hierarchy section

Project generated successfully!
```
