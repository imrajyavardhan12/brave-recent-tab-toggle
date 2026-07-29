import { toggleRecentTab } from "./tab-toggle.js";

const NATIVE_HOST = "org.recenttabtoggle.host";

export function startBackground(browser) {
  let status = { helper: "connecting", hotkey: "unknown" };
  let toggleQueue = Promise.resolve();
  const enqueueToggle = (options) => {
    const toggle = () => toggleRecentTab(browser, options);
    const result = toggleQueue.then(toggle, toggle);
    toggleQueue = result.catch(() => undefined);
    return result;
  };

  const nativePort = browser.runtime.connectNative(NATIVE_HOST);
  nativePort.onMessage.addListener((message) => {
    if (message.type === "toggle") {
      return enqueueToggle();
    }
    if (message.type === "status") {
      status = { helper: message.helper, hotkey: message.hotkey };
    }
  });

  nativePort.onDisconnect.addListener(() => {
    status = {
      helper: "disconnected",
      hotkey: "inactive",
      error: browser.runtime.lastError?.message ?? "native helper disconnected",
    };
  });

  browser.runtime.onMessage.addListener((message) => {
    if (message.type === "get-status") {
      return browser.windows
        .getLastFocused({ windowTypes: ["normal"] })
        .then((window) => ({
          ...status,
          profile:
            message.source === "action-popup" || window.focused
              ? "focused"
              : "unfocused",
        }))
        .catch(() => ({ ...status, profile: "unavailable" }));
    }
    if (message.type === "test-toggle") {
      return enqueueToggle({
        requireFocusedWindow: message.source !== "action-popup",
      });
    }
  });

  browser.commands.onCommand.addListener((command) => {
    if (command === "toggle-recent-tab") {
      return enqueueToggle();
    }
  });
}
