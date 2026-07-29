# Manual Test Plan

Run `make test` before these checks. Use a disposable Brave profile when practical.

## Installation

1. Run `./scripts/install.sh` without administrator privileges.
2. Load `extension/` from `brave://extensions`.
3. Confirm the extension ID is `edcgmlcjhdpdanpfhgcnbkeppbaijbmd`.
4. Run `./scripts/doctor.sh` and confirm every check passes.
5. Open the popup and confirm helper **Connected**, shortcut **active**, and profile **focused**.

## Core toggle

1. Activate tabs A → B → C.
2. Press Control–grave; confirm B is active.
3. Press it again; confirm C is active.
4. Trigger rapid repeated presses; confirm each press alternates once.

## Lifecycle cases

- Close B after A → B → C; from C, confirm the toggle activates A.
- With one tab, confirm the shortcut is a silent no-op.
- Confirm pinned, grouped, collapsed-group, and discarded tabs remain eligible.
- Restart Brave with restored tabs and confirm toggling follows Chromium’s retained activation metadata.

## Window and profile boundaries

- Open two windows; confirm each window maintains its own previous tab.
- Focus DevTools; confirm the shortcut does not change a normal tab.
- Open windows from two profiles; confirm only the profile owning the focused window changes.
- Switch to another application; confirm Control–grave is not consumed by the helper.

## Diagnostics and fallback

- Remove the compatibility native manifest, confirm disconnection, restore it, then reopen the popup and confirm reconnection without reloading the extension.
- Assign a supported key at `brave://extensions/shortcuts` and confirm it still toggles without the helper.
- Use **Test toggle** and confirm success/no-previous-tab feedback.

## Uninstallation

1. Run `./scripts/uninstall.sh`.
2. Confirm the helper binary and native manifest are removed.
3. Remove the extension from Brave.
4. Confirm Control–grave remains available to Brave or other applications.
