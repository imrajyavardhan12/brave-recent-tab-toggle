import assert from "node:assert/strict";
import test from "node:test";

import { toggleRecentTab } from "../src/tab-toggle.js";

function browserWith({ focused = true, tabs }) {
  const activatedTabIds = [];
  let clock = Math.max(0, ...tabs.map((tab) => tab.lastAccessed ?? 0)) + 1;

  return {
    activatedTabIds,
    windows: {
      async getLastFocused() {
        return { id: 7, focused, type: "normal" };
      },
    },
    tabs: {
      async query() {
        return tabs;
      },
      async update(tabId, update) {
        assert.deepEqual(update, { active: true });
        for (const tab of tabs) tab.active = tab.id === tabId;
        const activatedTab = tabs.find((tab) => tab.id === tabId);
        activatedTab.lastAccessed = clock++;
        activatedTabIds.push(tabId);
      },
    },
  };
}

test("a tab toggle activates the previous tab in the focused browser window", async () => {
  const browser = browserWith({
    tabs: [
      { id: 10, active: false, lastAccessed: 100 },
      { id: 11, active: false, lastAccessed: 300 },
      { id: 12, active: true, lastAccessed: 400 },
    ],
  });

  const result = await toggleRecentTab(browser);

  assert.deepEqual(browser.activatedTabIds, [11]);
  assert.deepEqual(result, { status: "toggled", tabId: 11 });
});

test("a closed previous tab exposes the next existing recent tab", async () => {
  const browser = browserWith({
    tabs: [
      { id: 10, active: false, lastAccessed: 100 },
      { id: 12, active: true, lastAccessed: 400 },
    ],
  });

  const result = await toggleRecentTab(browser);

  assert.deepEqual(browser.activatedTabIds, [10]);
  assert.deepEqual(result, { status: "toggled", tabId: 10 });
});

test("repeated tab toggles alternate between the same two tabs", async () => {
  const browser = browserWith({
    tabs: [
      { id: 10, active: false, lastAccessed: 100 },
      { id: 11, active: false, lastAccessed: 300 },
      { id: 12, active: true, lastAccessed: 400 },
    ],
  });

  await toggleRecentTab(browser);
  await toggleRecentTab(browser);

  assert.deepEqual(browser.activatedTabIds, [11, 12]);
});

test("a profile without the focused browser window does not toggle", async () => {
  const browser = browserWith({
    focused: false,
    tabs: [
      { id: 10, active: false, lastAccessed: 100 },
      { id: 11, active: true, lastAccessed: 200 },
    ],
  });

  const result = await toggleRecentTab(browser);

  assert.deepEqual(browser.activatedTabIds, []);
  assert.deepEqual(result, { status: "ignored", reason: "window-not-focused" });
});

test("a browser window with no previous tab is left unchanged", async () => {
  const browser = browserWith({
    tabs: [{ id: 10, active: true, lastAccessed: 100 }],
  });

  const result = await toggleRecentTab(browser);

  assert.deepEqual(browser.activatedTabIds, []);
  assert.deepEqual(result, { status: "ignored", reason: "no-previous-tab" });
});
