import assert from "node:assert/strict";
import test from "node:test";

import { NativeHostConnection } from "../src/native-host-connection.js";

function event() {
  const listeners = [];
  return {
    addListener(listener) {
      listeners.push(listener);
    },
    dispatch(value) {
      for (const listener of listeners) listener(value);
    },
  };
}

function nativeBrowser() {
  const ports = [];
  const browser = {
    runtime: {
      lastError: undefined,
      connectNative(hostName) {
        assert.equal(hostName, "org.recenttabtoggle.host");
        const port = {
          onMessage: event(),
          onDisconnect: event(),
          disconnect() {},
        };
        ports.push(port);
        return port;
      },
    },
  };
  return { browser, ports };
}

test("a native helper that never completes its handshake is disconnected", async () => {
  const { browser, ports } = nativeBrowser();
  let disconnected = false;
  const connection = new NativeHostConnection(browser, {
    handshakeTimeout: 0,
    retryDelays: [],
  });
  connection.start();
  ports[0].disconnect = () => {
    disconnected = true;
  };
  await new Promise((resolve) => setTimeout(resolve, 0));

  assert.equal(disconnected, true);
  assert.deepEqual(connection.getStatus(), {
    helper: "disconnected",
    hotkey: "inactive",
    error: "native helper handshake timed out",
  });
});

test("a synchronous native connection failure remains recoverable", async () => {
  const { browser, ports } = nativeBrowser();
  const connectNative = browser.runtime.connectNative;
  let attempts = 0;
  browser.runtime.connectNative = (...args) => {
    if (attempts++ === 0) throw new Error("native messaging unavailable");
    return connectNative(...args);
  };
  const connection = new NativeHostConnection(browser);

  assert.doesNotThrow(() => connection.start());
  const statusPromise = connection.retryNow();
  ports[0].onMessage.dispatch({
    type: "status",
    helper: "connected",
    hotkey: "active",
  });

  assert.equal((await statusPromise).helper, "connected");
});

test("automatic native helper retries are bounded", async () => {
  const { browser, ports } = nativeBrowser();
  const connection = new NativeHostConnection(browser, { retryDelays: [0, 0] });
  connection.start();
  browser.runtime.lastError = { message: "native host not found" };

  ports[0].onDisconnect.dispatch();
  await new Promise((resolve) => setTimeout(resolve, 0));
  ports[1].onDisconnect.dispatch();
  await new Promise((resolve) => setTimeout(resolve, 0));
  ports[2].onDisconnect.dispatch();
  await new Promise((resolve) => setTimeout(resolve, 0));

  assert.equal(ports.length, 3);
  assert.equal(connection.getStatus().helper, "disconnected");
});

test("reconnection waits for the helper's settled hotkey status", async () => {
  const { browser, ports } = nativeBrowser();
  const connection = new NativeHostConnection(browser);
  connection.start();
  browser.runtime.lastError = { message: "native host not found" };
  ports[0].onDisconnect.dispatch();

  let settled = false;
  const statusPromise = connection.retryNow().then((status) => {
    settled = true;
    return status;
  });
  ports[1].onMessage.dispatch({
    type: "status",
    helper: "connected",
    hotkey: "unknown",
  });
  await new Promise((resolve) => setTimeout(resolve, 0));
  assert.equal(settled, false);

  ports[1].onMessage.dispatch({
    type: "status",
    helper: "connected",
    hotkey: "active",
  });
  assert.equal((await statusPromise).hotkey, "active");
});

test("a disconnected native helper reconnects immediately when requested", async () => {
  const { browser, ports } = nativeBrowser();
  const connection = new NativeHostConnection(browser);
  connection.start();
  browser.runtime.lastError = { message: "native host not found" };
  ports[0].onDisconnect.dispatch();

  const statusPromise = connection.retryNow();
  ports[1].onMessage.dispatch({
    type: "status",
    helper: "connected",
    hotkey: "active",
  });

  assert.deepEqual(await statusPromise, {
    helper: "connected",
    hotkey: "active",
  });
  assert.equal(ports.length, 2);
});
