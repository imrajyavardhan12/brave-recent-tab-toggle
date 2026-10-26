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
# Operating-system and editor droppings that may sit beside shipped files. Any other file
# git does not track under a shipped directory could be one the extension needs.
JUNK_NAMES = {".DS_Store", "Thumbs.db", "desktop.ini", "4913"}
JUNK_PREFIXES = ("._", ".#")
JUNK_SUFFIXES = (".swp", ".swo", ".swn", ".swx", ".pyc", "~")
JUNK_DIRECTORIES = {"__pycache__", ".vscode", ".idea"}


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
    referenced = _manifest_references(project_root)
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
    # Shipping only tracked files keeps droppings such as .DS_Store out of the archive, so a
    # clean checkout of a commit packages identically on every machine (working-tree edits
    # to tracked files still ship). Any other file git does not track, ignored or not, is
    # probably one the extension needs, so it stops packaging instead of silently missing.
    pathspecs = ["--"] + [f"extension/{directory}" for directory in directories]
    # Unmerged files are listed once per conflict stage and may hold conflict markers.
    if _git(project_root, "--unmerged", *pathspecs):
        raise SystemExit("resolve merge conflicts in the extension before packaging")
    # Without --exclude-standard, ignore rules (including a contributor's global excludes)
    # cannot hide a file from this check.
    untracked = [
        name
        for name in _git(project_root, "--others", *pathspecs)
        if not _is_junk(name)
    ]
    if untracked:
        raise SystemExit(
            "extension files git does not track would not be packaged; add them "
            "(with `git add -f` if ignored) or remove them:\n  "
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


def _is_junk(name):
    *directories, basename = name.split("/")
    if JUNK_DIRECTORIES.intersection(directories):
        return True
    emacs_autosave = (
        len(basename) > 1 and basename.startswith("#") and basename.endswith("#")
    )
    return (
        basename in JUNK_NAMES
        or basename.startswith(JUNK_PREFIXES)
        or basename.endswith(JUNK_SUFFIXES)
        or emacs_autosave
    )


def _manifest_references(project_root):
    # manifest-references.mjs owns the one definition of the files manifest.json names.
    try:
        listing = subprocess.run(
            [
                "node",
                str(project_root / "scripts/manifest-references.mjs"),
                str(project_root / "extension/manifest.json"),
            ],
            capture_output=True,
            check=True,
        ).stdout
    except OSError as error:
        raise SystemExit(f"packaging requires Node.js: {error}") from error
    except subprocess.CalledProcessError as error:
        raise SystemExit(f"manifest.json is invalid: {_reason(error)}") from error
    references = [path for path in listing.decode().splitlines() if path]
    # An empty listing means the command printed nothing, never a manifest without files.
    if not references:
        raise SystemExit("manifest-references.mjs listed no files for manifest.json")
    return references


def _reason(error):
    stderr = error.stderr.decode(errors="replace").strip()
    return stderr or f"exited with status {error.returncode}"


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
        raise SystemExit(
            f"cannot list the extension's git files: {_reason(error)}"
        ) from error
    try:
        return [name.decode() for name in listing.split(b"\0") if name]
    except UnicodeDecodeError as error:
        # Zip archives store UTF-8 names, so such a file could not be packaged anyway.
        raise SystemExit(
            f"extension file names must be valid UTF-8: {error}"
        ) from error


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
