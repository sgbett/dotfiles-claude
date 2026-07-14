# Code Comments

How to write code that needs few comments, and what the remaining comments must do. The operative rules live in the `## Comments` section of `CLAUDE.md`; this document carries the worked examples and nuance. Distilled from the fuller treatment in `commands/deslop.md` (Self-Documenting Code, Documentation Discipline, SLAP).

**The principle:** code is the single source of truth for *what* it does. A comment restating the code is a second, unverifiable copy — it can't compile, can't be tested, and rots silently. Comments exist for the one thing code cannot express: *why*.

## First, write code that doesn't need the comment

Most "what" comments signal that the code could carry the meaning itself. Three techniques, each of which deletes a would-be comment.

### Name it

Intention-revealing names put the explanation in the code.

```ruby
# ❌ The name says nothing, so a comment picks up the slack
# calculate billable hours from days and weeks
def proc_hrs(d, w)
  d * w * 8
end

# ✅ The names are the comment
HOURS_PER_DAY = 8

def calculate_billable_hours(days_worked, weeks)
  days_worked * weeks * HOURS_PER_DAY
end
```

Conventions: methods are verbs (`calculate_total`, `validate_input`); predicates end in `?` (`active?`, `permitted?`); spell words out (`user_count`, not `usr_cnt`) — abbreviations force mental translation.

### Extract it

A header comment over a block is a missing method. Extract it and the name replaces the comment.

```ruby
# ❌ Section-header comment marks a missing abstraction
# validate email format
raise ArgumentError, 'invalid email' unless email.match?(EMAIL_PATTERN)

# ✅ The method name replaces the comment
validate_email_format(email)
```

Applied throughout, this produces the "stepdown" shape: a high-level method reads as a narrative of named steps, each at the same level of abstraction, no commentary required.

```ruby
def generate_monthly_report(month, year)
  data = fetch_monthly_data(month, year)
  metrics = calculate_metrics(data)
  charts = generate_visualisations(metrics)
  compile_report(metrics, charts)
end
```

**Caveat — don't over-extract.** A three-line method is already at one level; extraction for its own sake forces readers to jump between fragments. Test code in particular favours explicit inline steps over extraction.

### Constant-ify it

Magic values need explaining; named constants explain themselves.

```ruby
# ❌
sleep 0.5 if retry_count > 3 # max 3 retries, half-second delay

# ✅
MAX_RETRIES = 3
RETRY_DELAY_SECONDS = 0.5

sleep RETRY_DELAY_SECONDS if retry_count > MAX_RETRIES
```

## What earns a comment

A closed list of five. Every entry explains *why* — knowledge outside the code's semantics that no amount of naming can recover.

**Why** — rationale you can't infer from the code: a business rule, spec/RFC clause, or issue reference.

```ruby
# Orders over £1000 require manager approval per SOX compliance (POLICY-2019-04)
require_approval(order) if order.total > MANAGER_APPROVAL_THRESHOLD
```

**Why-not** — a rejected alternative and the reason, so the "obvious improvement" doesn't get re-attempted.

```ruby
# Linear search, not binary: the list is always <10 items and keeping it
# sorted would cost more than the lookup saves.
match = codes.find { |code| code.prefix == prefix }
```

**Workaround** — an external constraint (library bug, platform quirk), with a link so it can be removed when fixed upstream.

```ruby
# Net::HTTP retries idempotent requests by default, double-firing our webhook
# on timeout — https://github.com/example/upstream/issues/1234
http.max_retries = 0
```

**Warning** — a footgun that would otherwise catch the next reader.

```ruby
# Don't replace with Time.now — ledger ordering requires the DB clock so
# concurrent writers agree.
timestamp = connection.select_value('SELECT now()')
```

**Attribution** — the source of a borrowed algorithm or technique.

```ruby
# Algorithm from https://stackoverflow.com/a/46018816 (CC BY-SA)
```

## Anti-patterns — never write these

| Anti-pattern | Example | Fix |
|--------------|---------|-----|
| **Parrot** | `i += 1 # increment i` | Delete — the code already says it |
| **Rotting** | Comment describes code that changed | Update or delete in the same edit as the code |
| **Journal** | `# Fixed by John, 3/15` | Delete — `git blame` has this |
| **Commented-out code** | Dead code polluting the file | Delete — git has the history |
| **Closing-brace** | `end # if valid` | Extract smaller methods instead |
| **Mandated boilerplate** | A docstring on every method restating its signature | Comment only when it adds something |
| **TODO graveyard** | `# TODO: fix this (2019)` | Raise an issue or delete |

The parrot pattern, worked:

```ruby
# ❌ Every comment restates the line below it
def calculate_tax(amount)
  tax_rate = 0.08     # set tax rate to 0.08
  amount * tax_rate   # return amount times tax rate
end

# ✅ One comment, carrying information the code cannot
# California state rate as of 2024; updates tracked in POLICY-TAX-01
CA_TAX_RATE = 0.08

def calculate_tax(amount)
  amount * CA_TAX_RATE
end
```

## Docstrings and API docs

Document the contract — non-obvious behaviour, parameter semantics, what it raises — never the signature.

```ruby
# ❌ Restates the signature
# Adds two integers.
# @param a [Integer] first integer
# @param b [Integer] second integer
# @return [Integer] the sum
def add(a, b) = a + b

# ✅ Documents behaviour the signature can't express
# Free shipping over £100; Highlands and Islands add a flat £15 (never free).
# @raise [InvalidAddressError] if the shipping address is incomplete
def calculate_shipping(order)
```

## The documentation pyramid

Put each fact at the highest level that fits, once — single source of truth.

| Layer | Audience | Carries |
|-------|----------|---------|
| **README** | New users/devs | First contact, setup, overview |
| **API docs** | Consumers | Contract, usage, edge cases |
| **Docstrings** | Callers | Non-obvious behaviour, raises |
| **Inline comments** | Maintainers | Why this specific implementation |

## Keeping comments true

Comments drift from code silently — nothing checks them. Two disciplines:

- **Same-edit rule:** when you change code, update or delete its comment in the same edit. Never leave the two disagreeing.
- **Review comments against code:** in code review, read each comment against the lines it describes; delete rather than let rot.

```ruby
# ❌ The comment now lies — code changed, comment didn't
def users
  # active users sorted by name
  User.where(status: 'active').order(:created_at)
end
```
