#!/usr/bin/env python3
import json
import select
import struct
import subprocess
import sys
import os
import shutil
import tempfile
import uuid

host = sys.argv[1]
sandbox = tempfile.mkdtemp(prefix="recent-tab-toggle-host-test.")
environment = os.environ.copy()
environment.update({
    "RTT_COORDINATION_ROOT": sandbox,
    "RTT_EVENT_NAMESPACE": f"org.recenttabtoggle.tests.{uuid.uuid4()}",
    "RTT_TARGET_BUNDLE_ID": "org.recenttabtoggle.tests.never-frontmost",
})
process = subprocess.Popen(
    [host],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    env=environment,
)


def read_message(timeout=5):
    ready, _, _ = select.select([process.stdout], [], [], timeout)
    if not ready:
        raise AssertionError("native host did not emit a message")
    header = process.stdout.read(4)
    if len(header) != 4:
        raise AssertionError("native host emitted an incomplete frame header")
    length = struct.unpack("<I", header)[0]
    payload = process.stdout.read(length)
    if len(payload) != length:
        raise AssertionError("native host emitted an incomplete frame payload")
    return json.loads(payload)


try:
    connecting = read_message()
    status = read_message()
    assert connecting == {
        "type": "status",
        "helper": "connected",
        "hotkey": "unknown",
    }
    assert status["type"] == "status"
    assert status["helper"] == "connected"
    assert status["hotkey"] in {"active", "inactive", "conflict"}
finally:
    process.stdin.close()
    process.wait(timeout=5)
    shutil.rmtree(sandbox, ignore_errors=True)

assert process.returncode == 0, process.stderr.read().decode()
print("✓ native host speaks Chromium native messaging")
