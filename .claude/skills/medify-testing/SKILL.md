---

name: medify-testing
description: Use when planning, creating, improving, or reviewing tests for the Medify project. Medify is an integrated system containing frontend, backend, and Arduino/embedded code. Focus on meaningful test coverage, cross-component contracts, and critical user/device flows rather than maximizing test count or coverage percentage.
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Medify Testing

## Overview

Build and maintain meaningful automated tests for Medify as one integrated system:

Frontend ↔ Backend ↔ Arduino / Embedded Device

The goal is not maximum test count or arbitrary coverage percentages.

The goal is confidence that important Medify behavior works correctly and that changes do not silently break interactions between components.

## Core Principles

1. Test behavior, not implementation details.
2. Prioritize realistic failure modes.
3. Prioritize critical flows before broad coverage.
4. Test component boundaries explicitly.
5. Prefer small, deterministic, maintainable tests.
6. Do not create tests only to increase coverage.
7. Do not modify production behavior merely to make testing easier.
8. Understand the code before choosing what to test.

## Before Writing Tests

Before creating or modifying tests:

1. Inspect the repository structure.
2. Identify:

   * Frontend
   * Backend
   * Arduino / embedded code
   * APIs
   * Communication protocols
   * Shared schemas/types
   * Persistence/database layer
   * Existing test infrastructure, if any
3. Identify the languages, frameworks, package managers, and build systems in use.
4. Check whether testing frameworks or test dependencies already exist.
5. Trace the behavior being tested through the relevant components.
6. Identify existing CI configuration that may eventually run the tests.

Do not assume a testing framework before inspecting the project.

Before writing the first tests for a component that currently has no tests, present a short test plan — what will be tested, in what priority order, and the proposed framework/dependencies for that component — and wait for approval before implementing. This applies separately per component: approval for the backend test plan does not cover the frontend or Arduino plans.

## When No Tests Exist

If the relevant component currently has no tests:

1. Do not attempt to test the entire codebase at once.
2. Identify the highest-risk and most important behaviors first.
3. Determine the smallest appropriate testing setup for the existing stack.
4. Prefer established testing tools already compatible with the project's ecosystem.
5. Avoid adding unnecessary frameworks or dependencies.
6. Create a small initial test suite that proves the setup works.
7. Run the tests and verify that the testing setup is reproducible.
8. Expand incrementally, with a new short plan (per "Before Writing Tests") for each subsequent component or major area.

Before adding a new test framework or dependency, explain why it is appropriate for the existing stack, what will be added, and what type of tests it will support — then wait for approval before installing anything or writing tests against it. Medify has three separate ecosystems (Flutter/Dart, Spring Boot, Arduino/embedded); a framework choice for one does not carry approval for the others.

## Test Priorities

Prioritize tests in this order when applicable:

### 1. Critical behavior

Test behavior that could cause:

* Incorrect medical/health data
* Incorrect device measurements
* Incorrect values displayed to the user
* Data corruption or loss
* Broken primary user flows
* Incorrect commands sent to/from the device

For Medify, the following flows should be treated as must-test integration flows when the relevant test infrastructure exists:

#### Device event to application state

Device sends event
→ Backend parses and validates it
→ Intake status changes
→ Database is updated
→ The updated state becomes available to the mobile application

Verify that the same intake identity, status, timestamps, and relevant metadata remain consistent throughout the flow.

#### Medication dispensing and confirmed intake

Scheduled intake
→ User approves the intake
→ Backend sends the dispense command
→ Device releases the medication
→ Device reports dispensing/status events
→ Intake compartment is emptied
→ Backend marks the intake as taken only after confirmation

Pay special attention to preventing an intake from being marked as taken before the compartment-empty confirmation is received.

### 2. Cross-component contracts

Test boundaries between:

* Arduino ↔ Backend
* Backend ↔ Frontend
* Backend ↔ Database
* Backend ↔ External services, if applicable

Verify:

* Field names
* Types
* Units
* Allowed ranges
* Enum/status values
* Timestamp formats
* Missing/null values
* Invalid payloads
* Error responses
* Serialization/deserialization

### 3. Failure handling

Test realistic failures such as:

* Device disconnected
* Device sends malformed data
* Sensor read fails
* Backend unavailable
* Request timeout
* Network interruption
* Invalid user input
* Database operation fails
* Duplicate message/request
* Partial response
* Unexpected status/value

### 4. Core business logic

Test deterministic logic independently where practical.

### 5. Edge cases

Add tests for edge cases when there is a plausible failure scenario.

Do not generate large numbers of hypothetical edge-case tests without evidence that they matter.

## WebSocket Contract Tests

The device-to-backend WebSocket protocol is an important Medify component boundary and should be tested explicitly.

Where relevant, verify the currently implemented message types and their required fields, including:

* `heartbeat`
* `ack`
* `event`

Test realistic protocol failures such as:

* Malformed JSON
* Unknown message type
* Missing required fields
* Missing `intakeId`
* Invalid `intakeId` type
* Syntactically valid but nonexistent `intakeId`
* Missing or invalid `commandId`
* Unexpected event type
* Duplicate acknowledgement or event
* Exceptions occurring while processing an otherwise valid message

Verify not only the response or log behavior, but also the connection behavior.

In particular, malformed or invalid individual messages should not terminate an otherwise valid device WebSocket session unless the production protocol explicitly requires disconnection.

Contract tests should use payloads that reflect the actual Arduino/backend protocol rather than invented schemas.

## Frontend Tests

Focus on user-visible behavior.

Test where relevant:

* Important user flows
* API success responses
* API failures
* Loading states
* Empty states
* Invalid input
* Missing/null data
* State transitions
* Async behavior
* Stale responses
* Error messages
* Correct rendering of medical/device data

Prefer testing what the user observes rather than internal component implementation.

Avoid tests that break solely because markup or internal component structure changed.

## Backend Tests

Test where relevant:

* Business logic
* API endpoints
* Request validation
* Response schemas
* Error handling
* Authentication/authorization
* Database operations
* Serialization/deserialization
* Device communication
* WebSocket message handling
* Timeout/retry behavior
* Duplicate requests/messages
* Boundary values
* Invalid or malformed device input

Separate unit tests from integration tests where doing so provides useful isolation.

## Arduino / Embedded Tests

Identify what can reasonably be tested without physical hardware.

Test where practical:

* Parsing
* Serialization
* Data conversion
* Validation
* State transitions
* Timing logic
* Boundary calculations
* Protocol handling
* Error states
* Retry/reconnection logic

Pay special attention to:

* Invalid sensor values
* Sensor failures
* Integer/type boundaries
* Buffer handling
* Message framing
* millis() rollover where relevant
* Communication loss
* Unexpected device state

Do not pretend hardware-dependent behavior has been verified if physical hardware was not involved.

Clearly distinguish:

* Host-testable logic
* Simulated hardware behavior
* Tests requiring the actual Arduino/device

## Integration Tests

Integration tests are especially important for Medify.

Test important flows across component boundaries.

Examples:

Arduino payload
→ backend parsing
→ validation
→ persistence/business logic

Backend response
→ frontend API layer
→ state
→ displayed value

WebSocket device event
→ backend handler
→ domain/service logic
→ persistence
→ state exposed to the frontend

Verify that both sides of a contract agree.

Do not duplicate the same contract manually in a test if a shared schema or source of truth can be used safely.

## End-to-End Tests

Use end-to-end tests selectively.

Prioritize the small number of flows that represent actual Medify usage.

Do not create E2E tests for every UI interaction.

Good E2E candidates include:

* A primary user workflow
* Device data reaching the expected UI
* Critical medical/health information being displayed correctly
* Medication dispensing followed by confirmed intake
* Important failure/recovery behavior

Mock hardware or external dependencies only when appropriate.

State clearly what is real and what is mocked.

## Mocks

Mock at system boundaries when isolation is useful.

Do not mock the behavior being tested.

Avoid excessive mocking that allows components to pass tests even when their real contracts are incompatible.

For cross-component contracts, prefer realistic payloads based on the actual implementation.

## Test Quality

Every test should have a clear reason to exist.

A good test should:

* Verify meaningful behavior
* Have a clear failure condition
* Be deterministic
* Be independent where practical
* Be readable
* Fail for a useful reason
* Avoid unnecessary coupling to implementation details

Do not add tests that merely execute code without asserting meaningful behavior.

## Production Code Changes

Do not change production behavior simply to make a test pass.

If production code appears incorrect:

1. Identify the issue.
2. Explain why the existing behavior is incorrect.
3. Distinguish the bug fix from the test addition.
4. Do not silently alter behavior as part of test creation.

If a bug is discovered while writing a test, stop and report it — do not fix it as part of the same task. Do not encode known incorrect behavior as the expected result. After approval to fix the bug, first add a regression test that demonstrates the expected correct behavior and fails against the current implementation, then fix the production code and verify that the test passes.

Small refactors for testability are allowed only when they preserve behavior and provide clear value.

If a refactor is substantial, propose it before implementing it.

## Running Tests

After adding or modifying tests:

1. Run the new tests.
2. Run the relevant existing test suite.
3. If practical, run broader affected tests.
4. Report failures accurately.
5. Do not claim a test passed unless it was actually executed successfully.

Medify has a different test runner per component (e.g. `flutter test` for the frontend, the backend's Maven/Gradle test task, and whatever host-based runner is set up for Arduino/embedded logic). When reporting results, state exactly which runner/command was executed for which component — do not report a generic "tests passed" across components.

If a test cannot be run because hardware, credentials, services, or environment are unavailable, state exactly what could not be verified.

## Reporting

After creating tests, report:

### Tests added

Briefly describe the behaviors covered.

### Why these tests

Explain why they were prioritized.

### Test results

State what was actually run (including the exact command/runner per component) and whether it passed.

### Remaining gaps

Identify important behavior that is still untested, especially:

* Cross-component flows
* Hardware-dependent behavior
* Critical failure scenarios

Do not list every theoretically possible missing test.

Prioritize meaningful gaps.

## The Bottom Line

For Medify:

Test important behavior first.

Pay special attention to:

Arduino ↔ Backend ↔ Frontend

Treat the dispensing-to-confirmed-intake flow and the device WebSocket contract as high-priority areas.

A small suite that catches real regressions is more valuable than hundreds of shallow tests.

Build coverage incrementally and verify every test you add.