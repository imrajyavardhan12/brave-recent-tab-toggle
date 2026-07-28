export async function toggleRecentTab(browser) {
  const window = await browser.windows.getLastFocused({
    windowTypes: ["normal"],
  });
  if (!window.focused) {
    return { status: "ignored", reason: "window-not-focused" };
  }

  const tabs = await browser.tabs.query({ windowId: window.id });
  const previousTab = tabs
    .filter((tab) => !tab.active && tab.id !== undefined)
    .sort((left, right) => right.lastAccessed - left.lastAccessed)[0];

  if (!previousTab) {
    return { status: "ignored", reason: "no-previous-tab" };
  }

  await browser.tabs.update(previousTab.id, { active: true });

  return { status: "toggled", tabId: previousTab.id };
}
