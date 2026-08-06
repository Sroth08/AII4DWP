# Structured Triage Summary

## Summary (one line)
Ticket T-1005: Teams audio is not working on three machines in the same meeting room.

## Impact (who/how many/business urgency)
- Affected user(s): At least three endpoints in one meeting room.
- Functional impact: Users cannot use audio in Teams meetings from that room.
- Scope: Multi-device issue in a shared physical location; potential room-level fault.
- Business urgency: High for meeting continuity and collaboration.

## Known facts
- Ticket reference: T-1005.
- Symptom: Teams audio is dead.
- Scope clue: Three machines in the same meeting room are affected.

## Missing information to gather
- Whether both microphone input and speaker output fail.
- Whether issue occurs only in Teams or also in other audio apps/system sounds.
- Shared hardware details: same dock, USB audio device, speakerphone, or room AV kit (to-verify).
- Recent room changes: cabling, firmware, Windows/driver updates, Teams updates.
- Whether affected devices show the expected playback/recording devices and levels.
- Whether one known-good laptop in the same room and same AV chain reproduces the issue.
- Whether issue is present in all meetings or a single meeting/session.

## Likely catagory
Collaboration endpoint / meeting room audio path or shared peripheral issue.

## First diagnostic step
Validate the room audio chain by testing one affected machine with Teams test call and Windows sound settings, then swap to a known-good headset directly on the laptop to isolate room peripheral path versus endpoint software configuration.
