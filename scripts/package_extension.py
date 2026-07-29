#!/usr/bin/env python3
"""Create a deterministic extension archive and checksum."""

import argparse
import hashlib
import json
import stat
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
    for directory in INCLUDED_DIRECTORIES:
        files.extend(
            path for path in (extension_root / directory).rglob("*") if path.is_file()
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
