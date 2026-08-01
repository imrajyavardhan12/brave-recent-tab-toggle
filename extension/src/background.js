import { NativeHostConnection } from "./native-host-connection.js";
import { toggleRecentTab } from "./tab-toggle.js";

export function startBackground(browser) {
  let toggleQueue = Promise.resolve();
  const enqueueToggle = (options) => {
    const toggle = () => toggleRecentTab(browser, options);
    const result = toggleQueue.then(toggle, toggle);
    toggleQueue = result.catch(() => undefined);
    return result;
  };

  const observeToggle = (result) => {
    result.catch((error) => {
      console.error("Recent Tab Toggle failed", error);
    });
    return result;
  };

  const nativeConnection = new NativeHostConnection(browser, {
    onMessage(message) {
      if (message.type === "toggle") return observeToggle(enqueueToggle());
    },
  });
  browser.runtime.onStartup.addListener(() => nativeConnection.start());
  nativeConnection.start();

  browser.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    let response;
    if (message.type === "get-status") {
      const currentStatus = nativeConnection.getStatus();
      const nativeStatus =
        message.source === "action-popup" &&
        (currentStatus.helper !== "connected" ||
          currentStatus.hotkey === "unknown")
          ? nativeConnection.retryNow()
          : Promise.resolve(currentStatus);
      response = Promise.all([
        nativeStatus,
        browser.windows.getLastFocused({ windowTypes: ["normal"] }),
      ])
        .then(([status, window]) => ({
          ...status,
          profile:
            message.source === "action-popup" || window.focused
              ? "focused"
              : "unfocused",
        }))
        .catch(() => ({
          ...nativeConnection.getStatus(),
          profile: "unavailable",
        }));
    } else if (message.type === "test-toggle") {
      response = enqueueToggle({
        requireFocusedWindow: message.source !== "action-popup",
      });
    } else {
      return false;
    }

    Promise.resolve(response).then(sendResponse, (error) => {
      sendResponse({
        status: "error",
        error: error instanceof Error ? error.message : String(error),
      });
    });
    return true;
  });

  browser.commands.onCommand.addListener((command) => {
    if (command === "toggle-recent-tab") {
      return observeToggle(enqueueToggle());
    }
  });
}
