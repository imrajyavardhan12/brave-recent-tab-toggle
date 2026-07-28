import assert from "node:assert/strict";
import test from "node:test";

import { presentDiagnostics } from "../popup/popup-view.js";

test("diagnostics clearly identify a working exact shortcut", () => {
  assert.deepEqual(
    presentDiagnostics({
      helper: "connected",
      hotkey: "active",
      profile: "focused",
    }),
    {
      summary: "Ready",
      tone: "success",
      helper: "Connected",
      hotkey: "Control + ` is active",
      profile: "This profile owns the focused window",
      detail: "",
    },
  );
});

test("diagnostics expose native helper connection errors", () => {
  const view = presentDiagnostics({
    helper: "disconnected",
    hotkey: "inactive",
    profile: "focused",
    error: "Specified native messaging host not found.",
  });

  assert.equal(view.summary, "Setup needed");
  assert.equal(view.detail, "Specified native messaging host not found.");
});
