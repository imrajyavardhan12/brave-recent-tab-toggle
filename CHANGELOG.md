# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions. This project uses semantic versioning.

## [Unreleased]

## [0.2.2] - 2026-10-25

### Fixed

- Keep a single hotkey leader when cleanup tools or an uninstall remove the coordination lock file while Brave is running.
- Detect a Control–grave shortcut reserved by another application by registering it exclusively.
- Warn during uninstallation when Brave is still running the removed helper.
- Stop idle native hosts from sending a status message to every profile each second, while still correcting a missed status update within five seconds.

### Removed

- The popup's Profile row, which always reported the focused profile once the popup took focus.

## [0.2.1] - 2026-08-01

### Fixed

- Wake the extension at browser startup so the exact shortcut works before the diagnostics popup is opened.

## [0.2.0] - 2026-07-29

### Fixed

- Use Chromium’s callback messaging contract across the declared Chromium 121+ range.
- Reconnect the native helper automatically and whenever diagnostics are opened.
- Surface native protocol write failures instead of silently discarding them.
- Register the native host in the compatibility directory scanned by current Brave macOS builds.
- Treat the action popup as belonging to its browser window when it temporarily owns focus.

### Added

- Atomic native-host installation and a full installation doctor.
- Deterministic extension archives with SHA-256 checksums.
- Formatting, workflow, shell, Python, manifest, and release quality gates.
- Automated, commit-pinned GitHub extension releases.
- Manifest V3 tab-toggle extension using Chromium activation metadata.
- Exact permission-free Control–grave shortcut through a Swift native helper.
- Focused-window and multi-profile safety gates.
- Diagnostics popup, test action, fallback shortcut support, and local help.
- Source install/uninstall scripts, extension packaging, automated tests, and CI.
- Architecture documentation, domain glossary, security policy, and ADRs.
