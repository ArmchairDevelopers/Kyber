# RFC 0001 Rollout Plan: Party System

## Feature Flags
- party_api_enabled
- party_join_token_enabled
- party_join_enabled

## Phases
Phase 1:
- Party CRUD + roster UI (hidden)
- Metrics/logs

Phase 2:
- Token issuance + validation
- Group join for private servers

Phase 3:
- Group join best-effort everywhere
- Placement hints (same team)

## Monitoring
- Join success rate
- Token validation failures
- Rate-limit hits
- Error distribution

## Rollback
- Disable flags; fall back to existing join flow.
