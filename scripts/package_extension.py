#!/usr/bin/env python3
"""Create a deterministic extension archive and checksum."""

import argparse
import hashlib
import json
import os
import stat
import subprocess
import zipfile
from pathlib import Path

ARCHIVE_TIMESTAMP = (1980, 1, 1, 0, 0, 0)
INCLUDED_DIRECTORIES = ("icons", "popup", "src")


def package(project_root):
    extension_root = project_root / "extension"
    manifest = json.loads((extension_root / "manifest.json").read_text())
    output_directory = project_root / "dist"
    output_directory.mkdir(parents=True, exist_ok=True)
    archive = output_directory / "recent-tab-toggle-extension-{}.zip".format(
        manifest["version"]
    )

    files = [extension_root / "manifest.json", project_root / "LICENSE"]
    files.extend(_tracked_files(project_root, INCLUDED_DIRECTORIES))
    referenced = [
        manifest["background"]["service_worker"],
        manifest["action"]["default_popup"],
        *manifest["icons"].values(),
        *manifest["action"]["default_icon"].values(),
    ]
    packaged = {os.path.normpath(path) for path in files}
    absent = [
        path
        for path in referenced
        if os.path.normpath(extension_root / path) not in packaged
    ]
    if absent:
        raise SystemExit(
            "files referenced by manifest.json would not be packaged:\n  "
            + "\n  ".join(absent)
        )

    with zipfile.ZipFile(
        archive,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as output:
        for path in sorted(files, key=lambda item: item.as_posix()):
            archive_name = (
                "LICENSE"
                if path == project_root / "LICENSE"
                else path.relative_to(extension_root).as_posix()
            )
            info = zipfile.ZipInfo(archive_name, ARCHIVE_TIMESTAMP)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            output.writestr(info, path.read_bytes(), compresslevel=9)

    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    checksum = archive.with_suffix(archive.suffix + ".sha256")
    checksum.write_text(f"{digest}  {archive.name}\n")
    print(archive)
    print(checksum)


def _tracked_files(project_root, directories):
    # Shipping only tracked files keeps ignored files such as .DS_Store out of the archive,
    # so a clean checkout of a commit packages identically on every machine (working-tree
    # edits to tracked files still ship). An untracked file that is not ignored is
    # probably a forgotten `git add`, so it stops packaging instead of silently missing.
    pathspecs = ["--"] + [f"extension/{directory}" for directory in directories]
    # Unmerged files are listed once per conflict stage and may hold conflict markers.
    if _git(project_root, "--unmerged", *pathspecs):
        raise SystemExit("resolve merge conflicts in the extension before packaging")
    untracked = _git(project_root, "--others", "--exclude-standard", *pathspecs)
    if untracked:
        raise SystemExit(
            "untracked extension files would not be packaged; add or remove them:\n  "
            + "\n  ".join(untracked)
        )
    files = [project_root / name for name in _git(project_root, *pathspecs)]
    missing = [
        str(path.relative_to(project_root)) for path in files if not path.is_file()
    ]
    if missing:
        raise SystemExit(
            "tracked extension files are missing from the working tree:\n  "
            + "\n  ".join(missing)
        )
    return files


def _git(project_root, *arguments):
    try:
        listing = subprocess.run(
            ["git", "-C", str(project_root), "ls-files", "-z", *arguments],
            capture_output=True,
            check=True,
        ).stdout
    except OSError as error:
        raise SystemExit(f"packaging requires git: {error}") from error
    except subprocess.CalledProcessError as error:
        reason = error.stderr.decode(errors="replace").strip()
        raise SystemExit(f"cannot list the extension's git files: {reason}") from error
    return [name for name in listing.decode().split("\0") if name]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--project-root",
        default=str(Path(__file__).resolve().parent.parent),
    )
    arguments = parser.parse_args()
    package(Path(arguments.project_root).resolve())


if __name__ == "__main__":
    main()
