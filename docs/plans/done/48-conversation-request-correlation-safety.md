# Conversation Request Correlation Safety

## Problem

Concurrent conversation sidebar hydration can issue multiple commands during the same platform clock tick. Time-derived correlation identifiers can therefore collide on platforms with coarse clock precision. The conversation command gateway indexes pending responses by correlation identifier, so a collision can replace an earlier waiter, route a response to the wrong section, and leave another request waiting until timeout.

## Scope

- Give every client-originated conversation command a UUID-backed correlation identifier from one shared generator.
- Reject a duplicate pending correlation identifier at the gateway boundary instead of replacing an existing waiter.
- Preserve concurrent workspace and session hydration; serialization is not part of the solution.
- Keep the daemon protocol and response envelope unchanged.

## Verification Goals

- Concurrent session queries have distinct correlation identifiers.
- Responses arriving out of order complete the matching query.
- A duplicate identifier is rejected without disturbing the original pending request.
- Client static analysis and focused conversation command/gateway tests pass.
