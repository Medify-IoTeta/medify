---
name: medify-code-review
description: Reviews Medify (Flutter frontend, Spring Boot backend, Arduino firmware) as one integrated system, tracing cross-component flows and protocol contracts. Use when asked to review or audit changes to the Medify codebase.
---

# Medify Code Review

Review Medify as one integrated system, not as isolated frontend, backend, and Arduino projects.

## Scope

Unless the user specifies otherwise, review only what has changed recently:
- If run inside a git repo, default to the diff against the base branch (or `origin/main` if no base is specified) plus any currently uncommitted changes.
- If the user explicitly asks for a full review ("review everything", "review the whole codebase"), review the entire repository instead, following the full process below (repository structure → boundaries → end-to-end flows).
- If it's ambiguous which mode applies, ask.

State at the start of the review which mode was used and what was in scope (e.g. "Full repository review" or "Diff review: commits X..Y, N files changed").

## Before reporting issues

1. Understand the repository structure.
2. Identify the frontend, backend, Arduino/embedded code, shared schemas, and communication boundaries.
3. Trace the main end-to-end flows through the system.
4. Inspect relevant tests and configuration.
5. Verify each finding against the actual implementation.

For a full repository review, do not begin reporting findings until the major components and their communication paths have been identified — code that looks wrong in isolation may be explained by something on the other side of a boundary. For a diff review, this applies at the scale of the change: understand the direct callers, consumers, and communication paths of the changed code before reporting findings about it.

## Review priorities

Prioritize:
1. Correctness and real bugs
2. Cross-component integration issues
3. Reliability and failure handling
4. Security
5. Data validation and API/protocol contracts
6. Concurrency, timing, and asynchronous behavior
7. Edge cases
8. Maintainability problems that create concrete risk
9. Style only when it materially affects readability or correctness

Do not invent issues just to produce findings.

## Frontend

Check:
- API request/response assumptions
- State management
- Async behavior and race conditions
- Loading and error states
- Input validation
- Null/undefined handling
- Stale data
- Incorrect assumptions about backend state
- Resource cleanup
- User-visible failure scenarios

## Backend

Check:
- API contracts
- Input validation
- Error handling
- Authentication/authorization where applicable
- Database consistency
- Concurrency
- Resource cleanup
- External/device communication
- Retry and timeout behavior
- Incorrect trust in frontend/device input
- Serialization/deserialization
- Boundary cases

## Arduino / Embedded

Check:
- Blocking operations and excessive delay()
- Timing assumptions
- Sensor read failures
- Invalid/out-of-range values
- Serial/network communication
- Parsing and message framing
- Buffer sizes and overflow risks
- Memory constraints
- State machine correctness
- Reconnection/retry behavior
- Hardware initialization failures
- Integer overflow and type/range mismatches
- millis() rollover where relevant
- Recovery after communication failure

## Integration

Trace important flows such as:

Arduino/device → communication protocol → backend → persistence/business logic → API → frontend

Verify across boundaries:
- Field names
- Types
- Units
- Allowed ranges
- Enum/status values
- Timestamp formats
- Null/missing values
- Error representation
- Message ordering
- Retry behavior
- Timeouts
- Duplicate messages
- Partial failures

Do not review components independently when behavior depends on another component.

Identify where each cross-component contract/protocol is defined. Flag duplicated protocol definitions (e.g. status/enum values, field layouts) that exist independently in Arduino, backend, and frontend code and can silently drift apart, even if they currently agree.

## Severity definitions

- **Critical:** Causes data loss, security exposure, crash, or incorrect medical/health data being recorded or displayed. Must fix before merge.
- **High:** Breaks a real user flow or integration path under realistic conditions (not just adversarial edge cases). Should fix before merge.
- **Medium:** Incorrect behavior in an edge case, degraded reliability, or a contract mismatch that hasn't caused a failure yet but plausibly will. Fix soon, not necessarily blocking.
- **Low:** Maintainability or minor correctness issue with limited blast radius. Optional improvement.

Assign the lowest severity that still honestly reflects the failure scenario — do not inflate severity to make a finding seem more important.

## Findings

Only report findings with a plausible failure scenario.

For each finding provide:

### [Severity] Short title

**Category:** Functional / Integration / Reliability / Security / Maintainability / Testing
**Location:** `path/to/file:line` or relevant symbol
**Problem:** What is wrong.
**Failure scenario:** A concrete situation in which the problem occurs.
**Impact:** What breaks or behaves incorrectly.
**Recommended fix:** The smallest appropriate fix.
**Confidence:** High / Medium / Low

Distinguish:
- Confirmed bug
- Likely issue requiring verification
- Optional improvement

Do not present speculation as a confirmed bug.

## Review behavior

- Do not modify code during the review unless explicitly asked to implement the fixes. Review first, report findings, then wait for the user.
- Report missing test coverage only when the untested behavior is important enough that a regression could realistically go unnoticed (e.g. an untested Arduino → backend critical path). Do not report missing tests for minor or low-risk functions.
- Read surrounding code before judging a line.
- Search for callers and consumers before claiming code is unused.
- Check both sides of APIs and protocols.
- Check existing tests before suggesting behavior changes.
- Do not recommend large refactors unless necessary to fix a concrete issue.
- Do not flag formatter/linter concerns unless they expose a real problem.
- Preserve intentional architecture unless there is evidence it is incorrect.
- Prefer minimal fixes over redesigns.