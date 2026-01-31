# RFC 0001 Threat Model: Party System

## Assets
- Party membership (who is in a party)
- Join tokens (authorization to join as party)
- Server selection intent (target_server_id)
- Player identifiers

## Threats
T1. Token replay: attacker reuses a party token to join private servers.
Mitigation: short TTL + signature + bind token to player_id + server_id.

T2. Party enumeration: attacker guesses party IDs/codes.
Mitigation: random codes (not sequential), rate-limit join attempts.

T3. Party spam / DoS: attacker creates many parties or triggers join floods.
Mitigation: account-based quotas, IP rate limits, per-party join attempt caps.

T4. Impersonation: attacker claims another player_id.
Mitigation: require authenticated identity consistent with Kyber auth model.

T5. Leakage: tokens in logs/screenshots.
Mitigation: redact tokens in logs; keep TTL short.

## Logging/Telemetry (privacy)
- Log only party_id and event type.
- Avoid storing raw tokens.
- Minimize retention.

## Security Requirements
- Tokens must be signed and validated by the component enforcing joins.
- Token TTL recommended: 30–120 seconds.
- Rate limits on create/join/token endpoints.
