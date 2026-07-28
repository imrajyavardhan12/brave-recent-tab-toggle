---
status: accepted
---

# Use macOS hotkey registration instead of keyboard interception

The helper will register the physical Control–grave shortcut with Carbon’s `RegisterEventHotKey` while Brave Stable is frontmost, rather than intercepting keyboard events with a `CGEventTap`. Carbon is a legacy API, but it remains available on supported macOS versions, successfully registers this key combination, surfaces registration failures, and—most importantly—does not require Accessibility or Input Monitoring permission.

## Consequences

The helper must observe frontmost-application changes and register or unregister the hotkey accordingly so it never consumes the shortcut in other applications. Hotkey registration is isolated behind an interface so a future macOS API change does not affect native messaging or extension logic.
