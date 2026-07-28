---
status: accepted
---

# Route shortcuts to the focused browser profile

Native shortcut events will be made available to every connected extension profile, but only the profile that owns Brave’s focused normal window may perform the toggle. A native host is launched per profile, so routing to whichever host first acquires the macOS hotkey could otherwise toggle tabs in an unfocused profile; focused-window gating makes one-event-per-profile fan-out safe.

## Consequences

The native hosts require lightweight cross-process coordination for hotkey ownership and event fan-out. The extension remains the authority on browser focus because the helper cannot reliably infer a Brave profile from a macOS window alone.
