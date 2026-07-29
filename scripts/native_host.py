#!/usr/bin/env python3
"""Install, remove, and diagnose the Recent Tab Toggle native host."""

import argparse
import base64
import hashlib
import json
import os
import platform
import re
import select
import shutil
import struct
import subprocess
import sys
import tempfile
import uuid
from dataclasses import dataclass
from pathlib import Path

EXTENSION_ID = "edcgmlcjhdpdanpfhgcnbkeppbaijbmd"
HOST_NAME = "org.recenttabtoggle.host"
HOST_FILENAME = "recent-tab-toggle-host"
MANIFEST_FILENAME = HOST_NAME + ".json"


@dataclass(frozen=True)
class NativeHostLayout:
    install_root: Path
    brave_user_data: Path
    compatibility_directory: Path
    cache_root: Path

    @classmethod
    def from_environment(cls):
        home = Path.home()
        return cls(
            install_root=Path(
                os.environ.get(
                    "RTT_INSTALL_ROOT",
                    home / "Library/Application Support/RecentTabToggle",
                )
            ),
            brave_user_data=Path(
                os.environ.get(
                    "RTT_BRAVE_USER_DATA_DIR",
                    home / "Library/Application Support/BraveSoftware/Brave-Browser",
                )
            ),
            compatibility_directory=Path(
                os.environ.get(
                    "RTT_CHROMIUM_NATIVE_HOST_DIR",
                    home
                    / "Library/Application Support/Google/Chrome/NativeMessagingHosts",
                )
            ),
            cache_root=Path(
                os.environ.get(
                    "RTT_CACHE_ROOT",
                    home / "Library/Caches/RecentTabToggle",
                )
            ),
        )

    @property
    def host(self):
        return self.install_root / "bin" / HOST_FILENAME

    @property
    def brave_manifest(self):
        return self.brave_user_data / "NativeMessagingHosts" / MANIFEST_FILENAME

    @property
    def compatibility_manifest(self):
        return self.compatibility_directory / MANIFEST_FILENAME

    @property
    def manifests(self):
        return (self.brave_manifest, self.compatibility_manifest)

    def install(self, source):
        source = Path(source).resolve()
        if not source.is_file() or not os.access(source, os.X_OK):
            raise RuntimeError(f"native host is missing or not executable: {source}")

        self.host.parent.mkdir(parents=True, exist_ok=True)
        _atomic_copy(source, self.host, 0o755)
        manifest = {
            "name": HOST_NAME,
            "description": "Recent Tab Toggle native macOS shortcut helper",
            "path": str(self.host.resolve()),
            "type": "stdio",
            "allowed_origins": [f"chrome-extension://{EXTENSION_ID}/"],
        }
        for path in self.manifests:
            path.parent.mkdir(parents=True, exist_ok=True)
            _atomic_json_write(path, manifest)

    def uninstall(self):
        for path in (self.host,) + self.manifests:
            try:
                path.unlink()
            except FileNotFoundError:
                pass
        for directory in (self.host.parent, self.install_root):
            try:
                directory.rmdir()
            except OSError:
                pass
        try:
            (self.cache_root / "native-host.lock").unlink()
        except FileNotFoundError:
            pass
        try:
            self.cache_root.rmdir()
        except OSError:
            pass


def _atomic_copy(source, destination, mode):
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}-",
        dir=destination.parent,
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        shutil.copyfile(source, temporary)
        temporary.chmod(mode)
        os.replace(temporary, destination)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def _atomic_json_write(destination, value):
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}-",
        dir=destination.parent,
        text=True,
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w") as file:
            json.dump(value, file, indent=2)
            file.write("\n")
            file.flush()
            os.fsync(file.fileno())
        temporary.chmod(0o644)
        os.replace(temporary, destination)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def _extension_id(public_key):
    digest = hashlib.sha256(public_key).digest()[:16]
    return "".join(
        chr(ord("a") + nibble) for byte in digest for nibble in (byte >> 4, byte & 15)
    )


def _read_exact(stream, length, timeout):
    data = bytearray()
    while len(data) < length:
        ready, _, _ = select.select([stream], [], [], timeout)
        if not ready:
            raise RuntimeError("native host protocol timed out")
        chunk = os.read(stream.fileno(), length - len(data))
        if not chunk:
            raise RuntimeError("native host protocol closed unexpectedly")
        data.extend(chunk)
    return bytes(data)


def _read_native_message(stream, timeout=5):
    length = struct.unpack("<I", _read_exact(stream, 4, timeout))[0]
    if length > 1024 * 1024:
        raise RuntimeError("native host emitted an invalid frame length")
    return json.loads(_read_exact(stream, length, timeout))


def _check_native_protocol(host):
    sandbox = tempfile.mkdtemp(prefix="recent-tab-toggle-doctor.")
    environment = os.environ.copy()
    environment.update(
        {
            "RTT_COORDINATION_ROOT": sandbox,
            "RTT_EVENT_NAMESPACE": f"org.recenttabtoggle.doctor.{uuid.uuid4()}",
            "RTT_TARGET_BUNDLE_ID": "org.recenttabtoggle.doctor.never-frontmost",
        }
    )
    process = subprocess.Popen(
        [str(host)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=environment,
        bufsize=0,
    )
    try:
        first = _read_native_message(process.stdout)
        second = _read_native_message(process.stdout)
        if first.get("type") != "status" or second.get("type") != "status":
            raise RuntimeError("native host did not emit status messages")
    finally:
        if process.stdin:
            process.stdin.close()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        shutil.rmtree(sandbox, ignore_errors=True)
    if process.returncode != 0:
        error = process.stderr.read().decode(errors="replace").strip()
        raise RuntimeError(error or "native host exited unsuccessfully")


class Doctor:
    def __init__(self):
        self.failures = 0

    def check(self, description, predicate, failure):
        try:
            result = predicate()
            if result is False:
                raise RuntimeError(failure)
        except Exception as error:  # noqa: BLE001
            self.failures += 1
            print(f"[fail] {description}: {error}")
        else:
            print(f"[ok]   {description}")


def doctor(layout, project_root):
    result = Doctor()
    manifest_path = project_root / "extension/manifest.json"

    result.check(
        "macOS is supported",
        lambda: platform.system() == "Darwin",
        "this project currently supports macOS only",
    )
    result.check(
        "native helper is installed and executable",
        lambda: layout.host.is_file() and os.access(layout.host, os.X_OK),
        "run ./scripts/install.sh",
    )

    def check_architecture():
        output = subprocess.check_output(["file", str(layout.host)], text=True)
        machine = platform.machine()
        if machine not in output and "universal binary" not in output:
            raise RuntimeError(f"installed helper does not support {machine}")

    if layout.host.exists():
        result.check("native helper supports this Mac", check_architecture, "")

    expected_manifest = {
        "name": HOST_NAME,
        "path": str(layout.host.resolve()),
        "type": "stdio",
        "allowed_origins": [f"chrome-extension://{EXTENSION_ID}/"],
    }

    def manifest_check(path, missing_message):
        if not path.is_file():
            raise RuntimeError(missing_message)
        value = json.loads(path.read_text())
        for key, expected in expected_manifest.items():
            if value.get(key) != expected:
                raise RuntimeError(f"{path} has an invalid {key}")

    result.check(
        "Brave native manifest is valid",
        lambda: manifest_check(
            layout.brave_manifest, "Brave native manifest is missing"
        ),
        "",
    )
    result.check(
        "compatibility native manifest is valid",
        lambda: manifest_check(
            layout.compatibility_manifest,
            "compatibility native manifest is missing",
        ),
        "",
    )

    def extension_manifest_check():
        value = json.loads(manifest_path.read_text())
        if value.get("permissions") != ["nativeMessaging"]:
            raise RuntimeError("extension permissions have drifted")
        if "host_permissions" in value:
            raise RuntimeError("extension unexpectedly requests site access")
        key = base64.b64decode(value["key"])
        if _extension_id(key) != EXTENSION_ID:
            raise RuntimeError("extension ID does not match native authorization")

    result.check(
        "extension identity and permissions are valid",
        extension_manifest_check,
        "",
    )

    brave = Path(
        os.environ.get(
            "RTT_BRAVE_BINARY",
            "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
        )
    )
    if not brave.exists():
        brave = (
            Path.home() / "Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
        )

    def brave_check():
        if not brave.is_file():
            raise RuntimeError("Brave Stable is not installed in a supported location")
        output = subprocess.check_output([str(brave), "--version"], text=True)
        match = re.search(r"Brave Browser (\d+)", output)
        if not match or int(match.group(1)) < 121:
            raise RuntimeError("Brave must use Chromium 121 or newer")

    result.check("Brave Stable is compatible", brave_check, "")
    if layout.host.is_file() and os.access(layout.host, os.X_OK):
        result.check(
            "native helper protocol responds",
            lambda: _check_native_protocol(layout.host),
            "",
        )

    if result.failures:
        print(f"\n{result.failures} check(s) failed.")
        return 1
    print("\nRecent Tab Toggle installation is healthy.")
    return 0


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    install_parser = subparsers.add_parser("install")
    install_parser.add_argument("--source", required=True)
    subparsers.add_parser("uninstall")
    doctor_parser = subparsers.add_parser("doctor")
    doctor_parser.add_argument(
        "--project-root",
        default=str(Path(__file__).resolve().parent.parent),
    )
    arguments = parser.parse_args()
    layout = NativeHostLayout.from_environment()

    if arguments.command == "install":
        layout.install(arguments.source)
        print(layout.host)
        return 0
    if arguments.command == "uninstall":
        layout.uninstall()
        return 0
    return doctor(layout, Path(arguments.project_root).resolve())


if __name__ == "__main__":
    sys.exit(main())
