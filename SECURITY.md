# Security Policy

## Supported versions

Until a stable binary release exists, only the current `main` branch is supported.

## Reporting a vulnerability

Use GitHub’s private security-advisory workflow when available. Do not publish exploit details in a public issue. Include the affected commit, macOS and Brave versions, reproduction steps, and expected impact.

## Security posture

Recent Tab Toggle intentionally:

- Requests no website host permissions.
- Reads no page content, URL, title, or browser-history data.
- Performs no network requests or telemetry.
- Authorizes native messaging from one pinned extension ID.
- Uses permission-free hotkey registration instead of keyboard interception.
- Activates only an existing tab in the currently focused normal Brave window.
- Installs user-scoped files without administrator privileges.

The source installer compiles the helper locally. Initial releases do not distribute unsigned native binaries.

## Local trust boundary

Any process running as the same macOS user can post user-scoped distributed notifications. Such a process could request a tab toggle, but cannot use this project to read browser data or select a tab outside the extension profile that owns the focused Brave window. A process already executing as the user can synthesize equivalent browser input directly; this channel does not create a higher-privilege boundary.
