# Changelog

All notable changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions. This project uses semantic versioning.

## [Unreleased]

### Fixed

- Register the native host in the compatibility directory scanned by current Brave macOS builds.
- Treat the action popup as belonging to its browser window when it temporarily owns focus.

### Added

- Manifest V3 tab-toggle extension using Chromium activation metadata.
- Exact permission-free Control–grave shortcut through a Swift native helper.
- Focused-window and multi-profile safety gates.
- Diagnostics popup, test action, fallback shortcut support, and local help.
- Source install/uninstall scripts, extension packaging, automated tests, and CI.
- Architecture documentation, domain glossary, security policy, and ADRs.
