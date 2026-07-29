const NATIVE_HOST = "org.recenttabtoggle.host";
const DEFAULT_RETRY_DELAYS = [1_000, 2_000, 4_000, 8_000, 16_000];

function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

export class NativeHostConnection {
  #browser;
  #onMessage;
  #retryDelays;
  #handshakeTimeout;
  #handshakeTimer;
  #port;
  #retryAttempt = 0;
  #retryTimer;
  #waiters = [];
  #status = { helper: "disconnected", hotkey: "inactive" };

  constructor(
    browser,
    {
      onMessage = () => {},
      retryDelays = DEFAULT_RETRY_DELAYS,
      handshakeTimeout = 5_000,
    } = {},
  ) {
    this.#browser = browser;
    this.#onMessage = onMessage;
    this.#retryDelays = retryDelays;
    this.#handshakeTimeout = handshakeTimeout;
  }

  start() {
    if (!this.#port) this.#connect();
  }

  getStatus() {
    return { ...this.#status };
  }

  retryNow() {
    if (
      this.#status.helper === "connected" &&
      this.#status.hotkey !== "unknown"
    ) {
      return Promise.resolve(this.getStatus());
    }
    if (this.#status.helper !== "connecting") {
      this.#cancelRetry();
      this.#retryAttempt = 0;
      this.#connect();
    }
    return new Promise((resolve) => this.#waiters.push(resolve));
  }

  #connect() {
    this.#status = { helper: "connecting", hotkey: "unknown" };
    let port;
    try {
      port = this.#browser.runtime.connectNative(NATIVE_HOST);
    } catch (error) {
      this.#status = {
        helper: "disconnected",
        hotkey: "inactive",
        error: errorMessage(error),
      };
      this.#resolveWaiters();
      this.#scheduleRetry();
      return;
    }
    this.#port = port;

    port.onMessage.addListener((message) => {
      if (this.#port !== port) return;
      if (message.type === "status") {
        this.#status = {
          helper: message.helper,
          hotkey: message.hotkey,
        };
        this.#cancelRetry();
        if (message.hotkey !== "unknown") {
          this.#cancelHandshake();
          this.#retryAttempt = 0;
          this.#resolveWaiters();
        }
      } else {
        this.#onMessage(message);
      }
    });

    port.onDisconnect.addListener(() => {
      if (this.#port !== port) return;
      this.#cancelHandshake();
      const error =
        this.#browser.runtime.lastError?.message ?? "native helper disconnected";
      this.#port = undefined;
      this.#status = {
        helper: "disconnected",
        hotkey: "inactive",
        error,
      };
      this.#resolveWaiters();
      this.#scheduleRetry();
    });

    this.#handshakeTimer = setTimeout(() => {
      if (this.#port !== port || this.#status.hotkey !== "unknown") return;
      this.#port = undefined;
      port.disconnect();
      this.#status = {
        helper: "disconnected",
        hotkey: "inactive",
        error: "native helper handshake timed out",
      };
      this.#resolveWaiters();
      this.#scheduleRetry();
    }, this.#handshakeTimeout);
    this.#handshakeTimer.unref?.();
  }

  #scheduleRetry() {
    if (this.#retryTimer || this.#retryAttempt >= this.#retryDelays.length) return;
    const delay = this.#retryDelays[this.#retryAttempt++];
    this.#retryTimer = setTimeout(() => {
      this.#retryTimer = undefined;
      if (!this.#port) this.#connect();
    }, delay);
    this.#retryTimer.unref?.();
  }

  #cancelHandshake() {
    if (this.#handshakeTimer !== undefined) clearTimeout(this.#handshakeTimer);
    this.#handshakeTimer = undefined;
  }

  #cancelRetry() {
    if (this.#retryTimer !== undefined) clearTimeout(this.#retryTimer);
    this.#retryTimer = undefined;
  }

  #resolveWaiters() {
    const status = this.getStatus();
    for (const resolve of this.#waiters.splice(0)) resolve(status);
  }
}
