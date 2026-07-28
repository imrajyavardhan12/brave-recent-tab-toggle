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

const profileLabels = {
  focused: "This profile owns the focused window",
  unfocused: "Another profile owns the focused window",
  unavailable: "No normal Brave window is focused",
};

export function presentDiagnostics(status) {
  const ready =
    status.helper === "connected" &&
    status.hotkey === "active" &&
    status.profile === "focused";
  const conflict = status.hotkey === "conflict";

  return {
    summary: ready ? "Ready" : conflict ? "Shortcut conflict" : "Setup needed",
    tone: ready ? "success" : conflict ? "danger" : "warning",
    helper: helperLabels[status.helper] ?? "Unknown",
    hotkey: hotkeyLabels[status.hotkey] ?? "Unknown",
    profile: profileLabels[status.profile] ?? "Unknown",
    detail: status.error ?? "",
  };
}
