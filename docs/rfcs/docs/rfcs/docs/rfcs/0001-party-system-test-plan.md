# RFC 0001 Test Plan: Party System

## Unit Tests
- Party CRUD transitions
- Token issuance/validation (happy + expired + wrong server)

## Integration Tests
- Multi-client join orchestration:
  - all succeed
  - one fails (server full)
- Token enforcement (invalid signature)

## E2E Scenarios
S1. 2 players create/join party → join server together → both in same server.
S2. 4 players party → server full → fail with SERVER_FULL.
S3. Token expired → re-issue token → join succeeds.
S4. Rate limit triggers after repeated token requests.

## Acceptance Criteria (MVP)
- High success rate for group joins to non-full servers.
- Clear error reasons surfaced.
- No regressions to solo join flows.
