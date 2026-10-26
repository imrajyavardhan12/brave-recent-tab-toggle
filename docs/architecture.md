# Architecture

## System flow

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

The Browser Runtime module owns Chromium event semantics and native-host lifecycle. It synchronously registers a browser-startup wake event so Brave starts the service worker and native connection before the first shortcut press. It uses callback responses supported by every declared Chromium version, retries failed native connections with bounded exponential backoff, and retries immediately when the diagnostics popup is opened.

### Native host

Brave starts one Swift native-messaging host per extension profile. Each host:

- Maintains a Chromium length-prefixed JSON connection on standard input/output.
- Participates in process leadership through an advisory file lock.
- Receives shortcut/status events through user-scoped distributed notifications.
- Writes toggle events to its own extension profile.

Only the elected host registers the physical Control–grave hotkey. It holds leadership while connected, but registers the hotkey only while Brave Stable is frontmost. Followers retry leadership after leader termination. If the lock file under Caches is removed, its leader steps down and one host leads on the recreated file, so a cleanup never yields two leaders. The leader repeats its hotkey state every five seconds so a host that missed a notification converges, and each host forwards only state changes, so idle hosts send no browser messages.

All profile hosts receive a shortcut event. The extension instance whose normal browser window is actually focused performs the toggle; all others ignore it. This makes one-event-per-profile fan-out safe at the profile boundary.

## Native host discovery

The source installer writes identical, extension-ID-restricted manifests to Brave’s user data directory and the Google Chrome compatibility directory. Current Brave macOS builds resolve native hosts through the latter on affected installations; dual registration preserves compatibility without granting unrelated extensions access because `allowed_origins` contains only Recent Tab Toggle’s pinned ID.

The Installation module owns all user-scoped paths, atomic binary/manifest replacement, removal, and diagnostics. `scripts/doctor.sh` validates extension identity, permissions, Brave compatibility, binary architecture, both manifests, and the live native-messaging protocol.

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
- No module uses the network or stores browsing data.

## Failure behavior

| Failure | Behavior |
|---|---|
| Helper absent or exits | Browser Runtime retries with bounded backoff; popup can force immediate retry |
| Shortcut registration fails | Popup reports a conflict; no interception or override is attempted |
| Leadership changes hands | After taking over from a previous leader, the new leader holds a conflict for 2.5 seconds (reported on the next 1-second tick, about 3 seconds in) while the previous holder releases the shortcut, so the popup does not flash a false conflict. A first leader at startup has no previous holder and reports a conflict at once |
| Another app registers the shortcut non-exclusively | Not detected; Carbon reports conflicts only between exclusive registrations |
| Previous tab closes | Next most recently active existing tab becomes eligible |
| No focused normal window | Toggle is ignored |
| Wrong profile receives fan-out | Toggle is ignored by focused-window gating |
| Leader host exits | A follower acquires the released lock and registers the shortcut |
| Lock file removed while hosts run | The leader of the removed file steps down and one host leads on the recreated file |

## Repository layout

```text
extension/       Manifest V3 extension, popup, and tests
native/          Swift package for protocol, coordination, and macOS hotkey
scripts/         Build, validation, installation, packaging, and integration tests
docs/adr/        Architectural decision records
CONTEXT.md       Canonical product language
```
