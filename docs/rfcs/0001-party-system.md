# RFC 0001: Party System for Kyber

## Summary
Add a "party" abstraction so friends can reliably join the same server together and, where possible, land on the same team/squad.

This RFC intentionally defines:
- a minimal viable feature (MVP)
- a stable API contract
- expected behaviors and failure modes
- a security/threat model
- a test plan
- a phased rollout plan

## Motivation
Current behavior (from community reports): squads exist but are random and there is no reliable “join together” flow.
Players repeatedly ask for: “party up with friends and join a server together.”

Kyber is a monorepo (Launcher/Proxy/API/etc.), so a party system should be treated as a cross-cutting feature.

## Goals
G1. Let users create/join/leave a party.
G2. Let a party join a target server together (“group join”).
G3. Best-effort co-location: same team; same squad if feasible.
G4. Don’t break existing join flows.
G5. Keep it implementable incrementally.

## Non-goals (for MVP)
N1. Full EA social graph replacement (friends list, rich presence).
N2. UI-polished invites on day one.
N3. Guaranteed same squad in all situations (capacity, balancing, restrictions).

## Terminology
- Party: a group of players who want to join the same server together.
- Party leader: the player who creates the party (can be reassigned).
- Party token: short-lived signed token used to authenticate “party join.”
- Group join: one action that triggers multiple members to join same server.

## User Stories
U1. Create party → share party code/link → friends join party.
U2. Select server → “Join as Party” → everyone attempts to join.
U3. If server is full, members get a single clear failure reason.
U4. If some members fail to join, the rest get status updates.

## Architecture (proposed)
A. Party membership state lives in the API service (authoritative).
B. Launcher is the UX surface: create/join party, show roster, pick server.
C. Proxy participates during join: validates party token and applies placement hints.

### Why API as authority?
- Easier persistence and consistency
- Server browser/launcher already calls API-like services in many designs
- Keeps Proxy lightweight and focused on session/join enforcement

## Data Model (logical)
Party:
- party_id (string, globally unique)
- leader_player_id (string)
- members: list of { player_id, display_name, joined_at, status }
- created_at, updated_at
- settings:
  - prefer_same_team: bool (default true)
  - prefer_same_squad: bool (default true)
  - max_party_size: int (default 4 or 8; TBD)
- join_intent:
  - target_server_id (optional)
  - requested_at (optional)

Member status:
- idle | ready | joining | joined | failed | left

## Join Semantics
### Group Join Flow (happy path)
1) Leader selects server in Launcher.
2) Launcher requests party join token from API:
   - includes party_id + server_id
3) Launcher triggers join for each member:
   - either user action on each client OR “deep link”/auto-launch if supported
4) Proxy validates token per joining client.
5) Proxy applies placement hints:
   - same team if possible
   - same squad if possible
6) Proxy/Server reports success/fail; API updates member status.

### Failure Modes
F1. Server full → fail all with reason "SERVER_FULL".
F2. Partial capacity → allow partial join OR fail all (policy toggle).
F3. Team balancing constraints → same team best-effort; otherwise fallback.
F4. Token expired → clients must request fresh token.

## Placement Policy (best-effort)
P1. Team: attempt place all members on leader’s team.
P2. Squad: if squad API exists, attempt to place in same squad.
P3. If constraints prevent placement, degrade gracefully:
    - same server > same team > same squad

## Rate Limits / Abuse Controls (high level)
- Party create per account: limited
- Join tokens: short TTL + signed
- Group join attempts: limited per minute
- Prevent “party spam” or brute-force server joins

## Open Questions
Q1. What is a stable "player_id" across Launcher/Proxy/API?
Q2. Where is the best place to store party membership (API vs Proxy)?
Q3. Does Proxy have the levers required for squad/team placement without Module changes?
Q4. Should group join be “all-or-nothing” or “best effort”?

## Implementation Plan (phased)
Phase 1: API-only + launcher UI stub
- Party CRUD
- roster display
- party codes
- no group join yet

Phase 2: Group Join (server join coordination)
- create join tokens
- proxy validates tokens
- group join status tracking

Phase 3: Placement improvements
- team preference
- squad preference
- observability + metrics

Phase 4: Invite UX polishing
- deep links
- invite flows
- richer error feedback

## Success Metrics
- % of party joins that result in same server for all members
- % on same team
- % on same squad
- median time to get all members in match
- reduced Discord support questions about “how to join together”
