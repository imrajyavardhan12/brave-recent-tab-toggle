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
environment.update(
    {
        "RTT_COORDINATION_ROOT": sandbox,
        "RTT_EVENT_NAMESPACE": f"org.recenttabtoggle.tests.{uuid.uuid4()}",
        "RTT_TARGET_BUNDLE_ID": "org.recenttabtoggle.tests.never-frontmost",
    }
)
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


def drain(host):
    messages = []
    while (message := read_message(host, 0)) is not None:
        messages.append(message)
    return messages


def collect_until(host, predicate, timeout=5):
    messages = []
    deadline = time.monotonic() + timeout
    while (remaining := deadline - time.monotonic()) > 0:
        message = read_message(host, remaining)
        if message is None:
            break
        messages.append(message)
        if predicate(message):
            break
    return messages


try:
    # Each host settles once it forwards the leader's hotkey state.
    for host in hosts:
        settled = collect_until(
            host,
            lambda message: (
                message.get("type") == "status" and message.get("hotkey") != "unknown"
            ),
        )
        assert settled and settled[-1].get("hotkey") != "unknown", settled
    time.sleep(0.3)
    for host in hosts:
        drain(host)

    # The leader repeats its state every five seconds; a repeat must not message the browser.
    time.sleep(5.5)
    idle_messages = [message for host in hosts for message in drain(host)]
    assert idle_messages == [], f"idle hosts sent browser messages: {idle_messages}"

    subprocess.run(
        [broadcaster_path, "--broadcast-toggle"],
        check=True,
        env=environment,
    )

    received = [
        collect_until(host, lambda message: message.get("type") == "toggle")
        for host in hosts
    ]
    # Leave time for a duplicate toggle to arrive before counting.
    time.sleep(0.5)
    for host, messages in zip(hosts, received):
        messages += drain(host)
        toggles = sum(message.get("type") == "toggle" for message in messages)
        assert toggles == 1, f"each browser profile must toggle once, not {toggles}"
finally:
    for host in hosts:
        if host.poll() is None:
            host.stdin.close()
            host.wait(timeout=5)
    shutil.rmtree(sandbox, ignore_errors=True)

print("✓ a shortcut event reaches every connected browser profile")
