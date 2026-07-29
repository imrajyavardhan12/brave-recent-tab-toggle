import assert from "node:assert/strict";
import test from "node:test";

import { startBackground } from "../src/background.js";

function event() {
  const listeners = [];
  return {
    addListener(listener) {
      listeners.push(listener);
    },
    dispatch(...args) {
      return Promise.all(listeners.map((listener) => listener(...args)));
    },
  };
}

function browserWithTwoTabs() {
  const onCommand = event();
  const onMessage = event();
  const onNativeMessage = event();
  const onNativeDisconnect = event();
  const activatedTabIds = [];
  const tabs = [
    { id: 20, active: false, lastAccessed: 100 },
    { id: 21, active: true, lastAccessed: 200 },
  ];
  let clock = 201;

  return {
    activatedTabIds,
    commands: { onCommand },
    runtime: {
      onMessage,
      lastError: { message: "native host not found" },
      connectNative() {
        return {
          onMessage: onNativeMessage,
          onDisconnect: onNativeDisconnect,
        };
      },
    },
    windows: {
      async getLastFocused() {
        return { id: 1, focused: true, type: "normal" };
      },
    },
    tabs: {
      async query() {
        return structuredClone(tabs);
      },
      async update(tabId) {
        for (const tab of tabs) tab.active = tab.id === tabId;
        tabs.find((tab) => tab.id === tabId).lastAccessed = clock++;
        activatedTabIds.push(tabId);
      },
    },
    events: { onCommand, onMessage, onNativeMessage, onNativeDisconnect },
  };
}

test("a native hotkey message performs a tab toggle", async () => {
  const browser = browserWithTwoTabs();
  startBackground(browser);

  await browser.events.onNativeMessage.dispatch({ type: "toggle" });

  assert.deepEqual(browser.activatedTabIds, [20]);
});

test("diagnostics report native helper and hotkey status", async () => {
  const browser = browserWithTwoTabs();
  startBackground(browser);
  await browser.events.onNativeMessage.dispatch({
    type: "status",
    helper: "connected",
    hotkey: "active",
  });

  const [status] = await browser.events.onMessage.dispatch({ type: "get-status" });

  assert.deepEqual(status, {
    helper: "connected",
    hotkey: "active",
    profile: "focused",
  });
});

test("diagnostics report when the native helper disconnects", async () => {
  const browser = browserWithTwoTabs();
  startBackground(browser);

  await browser.events.onNativeDisconnect.dispatch();
  const [status] = await browser.events.onMessage.dispatch({ type: "get-status" });

  assert.deepEqual(status, {
    helper: "disconnected",
    hotkey: "inactive",
    profile: "focused",
    error: "native host not found",
  });
});

test("the popup remains associated with its browser window after taking focus", async () => {
  const browser = browserWithTwoTabs();
  browser.windows.getLastFocused = async () => ({
    id: 1,
    focused: false,
    type: "normal",
  });
  startBackground(browser);

  const [status] = await browser.events.onMessage.dispatch({
    type: "get-status",
    source: "action-popup",
  });
  await browser.events.onMessage.dispatch({
    type: "test-toggle",
    source: "action-popup",
  });

  assert.equal(status.profile, "focused");
  assert.deepEqual(browser.activatedTabIds, [20]);
});

test("the diagnostics test action performs a tab toggle", async () => {
  const browser = browserWithTwoTabs();
  startBackground(browser);

  await browser.events.onMessage.dispatch({ type: "test-toggle" });

  assert.deepEqual(browser.activatedTabIds, [20]);
});

test("rapid fallback commands are processed in order", async () => {
  const browser = browserWithTwoTabs();
  startBackground(browser);

  await Promise.all([
    browser.events.onCommand.dispatch("toggle-recent-tab"),
    browser.events.onCommand.dispatch("toggle-recent-tab"),
  ]);

  assert.deepEqual(browser.activatedTabIds, [20, 21]);
});

test("the fallback extension command performs a tab toggle", async () => {
  const browser = browserWithTwoTabs();
  startBackground(browser);

  await browser.events.onCommand.dispatch("toggle-recent-tab");

  assert.deepEqual(browser.activatedTabIds, [20]);
});
