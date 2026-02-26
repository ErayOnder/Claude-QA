---
name: qa-thinking
description: >
  QA reasoning patterns for test case design. Auto-loaded by the analyzer agent.
  Contains ISTQB-based techniques: equivalence partitioning, boundary value analysis,
  state transition testing, decision tables, and risk-based testing patterns.
  Use when generating test cases, assessing coverage, or doing QA analysis.
---

# QA Thinking — Test Design Techniques

This skill teaches Claude to reason like a senior QA engineer when designing test cases.
It is automatically loaded by the `qa-analyzer` agent.

---

## Core Philosophy

> Test the right things, not everything.

The goal is **maximum bug detection with minimum test cases**. Every test case must earn
its place by targeting a real risk. Low-value tests dilute attention and slow CI.

---

## Technique 1: Equivalence Partitioning

Divide inputs into groups (partitions) that should behave identically. Test one
representative from each partition instead of every possible value.

**How to apply:**

1. Identify all input fields/parameters in changed code
2. For each input, define valid and invalid partitions
3. Pick ONE representative value per partition

**Example — Age field (must be 18–99):**
```
Valid partition:   18–99    → test with 45
Invalid partition: < 18     → test with 16
Invalid partition: > 99     → test with 101
Invalid partition: non-num  → test with "abc"
Invalid partition: empty    → test with ""
```

**Generates 5 test cases instead of 82.**

**Always create partitions for:**
- String fields: empty, valid, too-long, special chars, unicode, SQL injection attempt
- Number fields: zero, negative, valid range, above max, decimal when int expected
- Date fields: past, today, future, invalid format, leap day edge cases
- Dropdown/enum: each valid option, invalid option, null/unset
- File uploads: valid file, wrong type, oversized, empty file, malformed file
- Booleans: true, false, null/undefined

---

## Technique 2: Boundary Value Analysis (BVA)

Bugs cluster at the edges of valid ranges. Always test:
- **Min valid** (the boundary itself)
- **Min - 1** (just outside valid, should fail)
- **Max valid** (the boundary itself)  
- **Max + 1** (just outside valid, should fail)

**Example — Password length (8–64 chars):**
```
Test: 7 chars  → INVALID (min-1)
Test: 8 chars  → VALID   (min boundary)
Test: 9 chars  → VALID   (min+1, normal valid)
Test: 64 chars → VALID   (max boundary)
Test: 65 chars → INVALID (max+1)
```

**Apply BVA whenever you see:**
- Length limits on text inputs
- File size limits
- Pagination (first page, last page, empty)
- Rate limits
- Price/quantity ranges
- Date ranges

---

## Technique 3: State Transition Testing

For flows with multiple states, map every transition and test:
- **Happy path** through all states
- **Invalid transitions** (can user jump states?)
- **Interrupted flows** (what happens mid-flow?)
- **Repeated actions** (what happens doing same step twice?)

**Common state flows to test:**
```
Auth:      Logged out → Logged in → Session expired → Logged out
Cart:      Empty → Items added → Checkout started → Payment → Confirmed → Cancelled
Form:      Initial → Partial fill → Validation error → Completed → Submitted
Upload:    Selected → Uploading → Success | Failed → Retry
Account:   Active → Suspended → Reactivated | Deleted
```

**Key questions for each flow:**
- Can a user access state N+2 without going through state N+1?
- What happens if browser is refreshed mid-flow?
- What happens if the user hits Back?
- What happens if the session expires mid-flow?
- What happens if the same action is taken twice?

---

## Technique 4: Decision Table Testing

When behavior depends on combinations of conditions, create a decision table.

**Example — Discount eligibility:**
```
| Premium user | Order > $100 | First order | Discount |
|--------------|--------------|-------------|---------|
| Y            | Y            | Y           | 20%     |
| Y            | Y            | N           | 15%     |
| Y            | N            | Y           | 10%     |
| Y            | N            | N           | 5%      |
| N            | Y            | Y           | 10%     |
| N            | Y            | N           | 5%      |
| N            | N            | Y           | 5%      |
| N            | N            | N           | 0%      |
```

**Apply decision tables when:** code has multiple `if/else` conditions, feature has
multiple user tiers/roles, behavior changes based on combinations of flags/settings.

---

## Technique 5: Risk-Based Test Prioritization

Not all tests are equal. Prioritize using this matrix:

```
Risk = Likelihood of failure × Impact of failure
```

| Area | Likelihood | Impact | Priority |
|------|------------|--------|----------|
| Auth/login changes | HIGH | CRITICAL | Test first, test most |
| Payment flow | MEDIUM | CRITICAL | Test thoroughly |
| New feature (no tests) | HIGH | MEDIUM | Test core flows |
| Refactored logic | MEDIUM | MEDIUM | Test + regression |
| UI styling | LOW | LOW | Smoke test only |
| Config change | LOW | HIGH | Targeted test |
| Dependency update | MEDIUM | UNKNOWN | Regression sweep |

---

## Technique 6: Negative Path Patterns

These are the negative tests that catch the most bugs in real-world PRs:

### Input Attacks (test any user-facing input field)
- **SQL Injection:** `' OR '1'='1`
- **XSS:** `<script>alert('xss')</script>`
- **Path traversal:** `../../etc/passwd`
- **Null bytes:** `test\x00`
- **Unicode edge cases:** `𝕳𝖊𝖑𝖑𝖔` or RTL characters `مرحبا`
- **Extremely long string:** 10,000 characters

### Auth/Permission Tests
- Access protected endpoint without token → expect 401
- Access other user's resource → expect 403
- Use expired token → expect 401
- Use token from different environment → expect 401

### Concurrency/Race Conditions
- Submit form twice in rapid succession (double-click)
- Open same resource in two tabs and modify both
- Start long operation then navigate away

### API Contract Tests
- Send extra/unknown fields in request body
- Send wrong content-type header
- Send malformed JSON
- Omit required fields
- Send null for required fields

---

## Technique 7: Regression Impact Heuristics

When code changes, use these heuristics to find what else might break:

### Shared Module Changes
If a utility/helper was changed, find ALL its consumers:
```bash
grep -r "import.*[changed-module]" --include="*.ts" --include="*.js" .
grep -r "require.*[changed-module]" --include="*.ts" --include="*.js" .
```
Each consumer is a potential regression area.

### Database Model Changes
If a model was changed:
- Find all API endpoints that read/write that model
- Find all views/components that display that data
- Check if any other models reference it via foreign keys

### API Contract Changes
If an API endpoint signature changed:
- Find all frontend calls to that endpoint
- Find any external integrations/webhooks
- Check API documentation is updated

### Auth/Middleware Changes
If auth logic changed, test EVERY route category:
- Public routes (no auth) — still work
- Protected routes — still require auth
- Admin routes — still require admin
- Owner-only routes — still scoped to owner

---

## QA Output Standards

When producing test cases, always include:

```json
{
  "id": "TC-XXX",                    // Unique, sequential
  "title": "One line, action-oriented",
  "category": "happy_path|negative|boundary|state_transition|regression",
  "priority": 1-10,                  // 10 = most critical
  "required": true/false,            // true = must pass before merge
  "description": "What and why",
  "preconditions": ["..."],          // What must be true before test
  "steps": ["..."],                  // Concrete, automatable actions
  "expected_result": "...",          // Specific, verifiable outcome
  "test_type": "browser|api|unit",
  "related_files": ["..."]           // Changed files this tests
}
```

**Step writing rules:**
- Steps must be specific enough for Playwright to execute
- Use exact button text/labels when known (e.g., "Click 'Submit Order' button")
- Include what to wait for (e.g., "Wait for success toast to appear")
- Specify expected URLs after navigation
- Never use vague steps like "check the page" or "verify it works"

---

## Common Traps to Avoid

❌ **Don't test what you didn't change** — focus on the diff
❌ **Don't generate 30 test cases** — prioritize to 10-15 max
❌ **Don't write vague steps** — "verify the page loads" is not automatable
❌ **Don't ignore regression risks** — the change may break unmodified code
❌ **Don't assume only happy paths matter** — negative tests catch more bugs
❌ **Don't test UI appearance manually** — use visual regression or skip
✅ **Do look at git history** — previous bugs in this file area are likely to recur
✅ **Do test the integration points** — where two changed systems meet
✅ **Do check for existing tests** — they tell you what was already validated
