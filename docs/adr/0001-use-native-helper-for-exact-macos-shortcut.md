---
status: accepted
---

# Use a native helper for the exact macOS shortcut

The product will pair a Manifest V3 browser extension with an optional native macOS helper, while retaining a Chromium-supported extension command as a fallback. Brave 150 rejects `Control + \`` both as a manifest-suggested command and when entered through `brave://extensions/shortcuts`; a native helper therefore provides the exact shortcut without the broad site access and incomplete browser coverage of content-script key capture.

## Consequences

The helper communicates with the extension through Chromium native messaging and only captures the shortcut while Brave is focused. Releases must package and install both the native host and its registration manifest, while users who do not install the helper can still assign a supported shortcut to the extension command.
