# Architecture

## Components

```text
Control + `
    │
    ▼
macOS native host leader ── distributed notification ──► host per Brave profile
                                                            │ native messaging
                                                            ▼
                                                     extension service worker
                                                            │
                                                            ▼
                                                   focused normal window only
                                                            │
                                                            ▼
                                                  previous existing tab
```

### Extension

The Manifest V3 extension owns browser semantics. On a native `toggle` message, fallback extension command, or popup test action it:

1. Gets the profile’s last-focused normal window.
2. Stops unless that window is currently focused.
3. Queries tabs in that window.
4. Selects the inactive tab with the greatest Chromium `lastAccessed` value.
5. Activates it.

Chromium updates `lastAccessed` on activation, so invoking the operation again naturally selects the former active tab. Toggle requests are serialized to avoid key-repeat races.

### Native host

Brave starts one Swift native-messaging host per extension profile. Each host:

- Maintains a Chromium length-prefixed JSON connection on standard input/output.
- Participates in process leadership through an advisory file lock.
- Receives shortcut/status events through user-scoped distributed notifications.
- Writes toggle events to its own extension profile.

Only the elected host registers the physical Control–grave hotkey. It holds leadership while connected, but registers the hotkey only while Brave Stable is frontmost. Followers retry leadership after leader termination.

All profile hosts receive a shortcut event. The extension instance whose normal browser window is actually focused performs the toggle; all others ignore it. This makes one-event-per-profile fan-out safe at the profile boundary.

## Native host discovery

The source installer writes identical, extension-ID-restricted manifests to Brave’s user data directory and the Google Chrome compatibility directory. Current Brave macOS builds resolve native hosts through the latter on affected installations; dual registration preserves compatibility without granting unrelated extensions access because `allowed_origins` contains only Recent Tab Toggle’s pinned ID.

## Native messaging protocol

Native messages use Chromium’s standard format: a four-byte little-endian payload length followed by UTF-8 JSON.

Host to extension messages:

```json
{"type":"toggle"}
{"type":"status","helper":"connected","hotkey":"active"}
```

`hotkey` is one of `active`, `inactive`, `conflict`, or initially `unknown`.

## Security boundaries

- The native manifest authorizes only the pinned extension origin.
- The extension has `nativeMessaging` permission and no site access.
- Profile focus is verified through the browser API, not inferred by the helper.
- The helper registers one declared hotkey and does not inspect keyboard input.
- Standard output is reserved exclusively for native protocol frames; diagnostics go to standard error.
- No component uses the network or stores browsing data.

## Failure behavior

| Failure | Behavior |
|---|---|
| Helper absent or exits | Popup reports disconnection; fallback extension command remains available |
| Shortcut registration fails | Popup reports a conflict; no interception or override is attempted |
| Previous tab closes | Next most recently active existing tab becomes eligible |
| No focused normal window | Toggle is ignored |
| Wrong profile receives fan-out | Toggle is ignored by focused-window gating |
| Leader host exits | A follower acquires the released lock and registers the shortcut |

## Repository layout

```text
extension/       Manifest V3 extension, popup, and tests
native/          Swift package for protocol, coordination, and macOS hotkey
scripts/         Build, validation, installation, packaging, and integration tests
docs/adr/        Architectural decision records
CONTEXT.md       Canonical product language
```
