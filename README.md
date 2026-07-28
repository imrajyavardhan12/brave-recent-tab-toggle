# Recent Tab Toggle

Edge-style last-active-tab toggling for Brave on macOS. Press **Control + `** to switch A → B → A between the two most recently active tabs in the focused Brave window.

> Independent open-source project; not affiliated with or endorsed by Brave Software.

## Why two components?

Chromium rejects the backtick key for extension commands, including shortcuts assigned through `brave://extensions/shortcuts`. Recent Tab Toggle therefore uses:

- A minimal Manifest V3 extension to select the previous tab.
- A small Swift helper to register the exact macOS shortcut and signal the extension.

The helper uses macOS hotkey registration—not keyboard interception—so it needs neither Accessibility nor Input Monitoring permission.

## Requirements

- macOS 13 or newer
- Brave Stable based on Chromium 121 or newer
- Apple Command Line Tools (`xcode-select --install`), used to build locally
- Apple silicon or Intel Mac

No paid Apple Developer account is required for source installation.

## Install from source

```sh
./scripts/install.sh
```

Then:

1. Open `brave://extensions`.
2. Enable **Developer mode**.
3. Select **Load unpacked**.
4. Choose this repository’s `extension/` directory.
5. Open at least two tabs and press **Control + `**.

The extension ID is pinned to `edcgmlcjhdpdanpfhgcnbkeppbaijbmd`, allowing Brave to authorize its native helper consistently.

## Diagnostics

Select the extension toolbar icon. The popup reports:

- Native helper connection
- Exact shortcut registration or conflicts
- Whether this profile owns the focused Brave window
- A test-toggle action

If the helper is not found after installation, reload the extension or restart Brave. The popup’s **Install & troubleshooting** link contains the complete checklist.

### Fallback shortcut

The extension core works without the helper. Open `brave://extensions/shortcuts` and assign a Chromium-supported shortcut to **Toggle the two most recently active tabs**.

## Behavior

- Toggle history is independent per Brave window.
- Multiple Brave profiles are supported; only the profile owning the focused window acts.
- Closed tabs are discarded, exposing the next most recently active existing tab.
- Pinned, grouped, collapsed, and discarded tabs participate normally.
- With fewer than two tabs, the command does nothing.
- The exact shortcut is active only while Brave Stable is frontmost.
- On non-US layouts, the native shortcut follows the physical ANSI grave-key position.

## Privacy and security

The extension requests only `nativeMessaging`. It has no host permissions and cannot read page content, titles, URLs, or browsing history. Neither component performs telemetry or network requests.

See [SECURITY.md](SECURITY.md) and [docs/architecture.md](docs/architecture.md).

## Development

```sh
make test       # extension, native, multi-profile, and installer tests
make build      # release-mode native helper
make install    # local source installation
make package    # create extension zip under dist/
make uninstall
```

The project uses dependency-free JavaScript tests and a dependency-free Swift package. Architectural decisions live in [`docs/adr/`](docs/adr/); GUI release checks are listed in [`docs/manual-test-plan.md`](docs/manual-test-plan.md).

## Uninstall

```sh
./scripts/uninstall.sh
```

Then remove the unpacked extension from `brave://extensions`.

## Current release model

Initial releases are source-installed. Downloadable helper binaries are intentionally deferred until signing and notarization credentials are available; the project does not distribute unsigned binaries that trigger avoidable Gatekeeper warnings.

## License

[MIT](LICENSE) © Recent Tab Toggle contributors.
