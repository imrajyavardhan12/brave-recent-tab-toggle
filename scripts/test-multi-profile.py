#!/usr/bin/env python3
import json
import os
import select
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import uuid

host_path, broadcaster_path = sys.argv[1:]
sandbox = tempfile.mkdtemp(prefix="recent-tab-toggle-profiles-test.")
environment = os.environ.copy()
environment.update({
    "RTT_COORDINATION_ROOT": sandbox,
    "RTT_EVENT_NAMESPACE": f"org.recenttabtoggle.tests.{uuid.uuid4()}",
    "RTT_TARGET_BUNDLE_ID": "org.recenttabtoggle.tests.never-frontmost",
})
hosts = [
    subprocess.Popen(
        [host_path],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        bufsize=0,
        env=environment,
    )
    for _ in range(2)
]


def read_message(host, timeout):
    ready, _, _ = select.select([host.stdout], [], [], timeout)
    if not ready:
        return None
    header = host.stdout.read(4)
    if len(header) != 4:
        raise AssertionError("incomplete native message header")
    length = struct.unpack("<I", header)[0]
    payload = host.stdout.read(length)
    if len(payload) != length:
        raise AssertionError("incomplete native message payload")
    return json.loads(payload)


try:
    for host in hosts:
        first = read_message(host, 5)
        assert first and first["type"] == "status"

    # Let leader election and status-request fan-out settle, then drain statuses.
    time.sleep(0.3)
    for host in hosts:
        while read_message(host, 0) is not None:
            pass

    subprocess.run(
        [broadcaster_path, "--broadcast-toggle"],
        check=True,
        env=environment,
    )

    for host in hosts:
        deadline = time.monotonic() + 5
        toggles = 0
        while time.monotonic() < deadline:
            message = read_message(host, deadline - time.monotonic())
            if message is None:
                break
            if message.get("type") == "toggle":
                toggles += 1
                break
        assert toggles == 1, "each browser profile must receive the toggle event"
finally:
    for host in hosts:
        if host.poll() is None:
            host.stdin.close()
            host.wait(timeout=5)
    shutil.rmtree(sandbox, ignore_errors=True)

print("✓ a shortcut event reaches every connected browser profile")
