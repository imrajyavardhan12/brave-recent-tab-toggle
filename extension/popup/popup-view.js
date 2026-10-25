const helperLabels = {
  connected: "Connected",
  connecting: "Connecting…",
  disconnected: "Not connected",
};

const hotkeyLabels = {
  active: "Control + ` is active",
  inactive: "Control + ` is inactive",
  conflict: "Control + ` is used by another application",
  unknown: "Waiting for helper status",
};

export function presentDiagnostics(status) {
  const ready = status.helper === "connected" && status.hotkey === "active";
  const conflict = status.hotkey === "conflict";

  return {
    summary: ready ? "Ready" : conflict ? "Shortcut conflict" : "Setup needed",
    tone: ready ? "success" : conflict ? "danger" : "warning",
    helper: helperLabels[status.helper] ?? "Unknown",
    hotkey: hotkeyLabels[status.hotkey] ?? "Unknown",
    detail: status.error ?? "",
  };
}
