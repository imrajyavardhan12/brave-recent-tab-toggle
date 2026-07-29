import { presentDiagnostics } from "./popup-view.js";

const elements = {
  summary: document.querySelector("#summary"),
  helper: document.querySelector("#helper"),
  hotkey: document.querySelector("#hotkey"),
  profile: document.querySelector("#profile"),
  detail: document.querySelector("#detail"),
  result: document.querySelector("#result"),
  testToggle: document.querySelector("#test-toggle"),
  shortcuts: document.querySelector("#shortcuts"),
};

async function refresh() {
  const status = await chrome.runtime.sendMessage({
    type: "get-status",
    source: "action-popup",
  });
  const view = presentDiagnostics(status);
  elements.summary.textContent = view.summary;
  elements.summary.dataset.tone = view.tone;
  elements.helper.textContent = view.helper;
  elements.hotkey.textContent = view.hotkey;
  elements.profile.textContent = view.profile;
  elements.detail.textContent = view.detail;
}

elements.testToggle.addEventListener("click", async () => {
  elements.testToggle.disabled = true;
  elements.result.textContent = "Testing…";
  try {
    const result = await chrome.runtime.sendMessage({
      type: "test-toggle",
      source: "action-popup",
    });
    elements.result.textContent =
      result.status === "toggled" ? "Toggle succeeded." : "No previous tab available.";
  } catch {
    elements.result.textContent = "Toggle failed. Check extension diagnostics.";
  } finally {
    elements.testToggle.disabled = false;
    await refresh();
  }
});

elements.shortcuts.addEventListener("click", async () => {
  try {
    await chrome.tabs.create({ url: "brave://extensions/shortcuts" });
  } catch {
    elements.result.textContent = "Open brave://extensions/shortcuts manually.";
  }
});

refresh().catch(() => {
  elements.summary.textContent = "Diagnostics unavailable";
  elements.summary.dataset.tone = "danger";
});
