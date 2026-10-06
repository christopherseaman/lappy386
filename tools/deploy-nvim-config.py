#!/usr/bin/env python3
"""Deploy managed Neovim files without pruning local files or copying lockfiles.

Keep one previous version of each replaced file in a separate backup directory.
Identical files and their backups are left untouched.
Parent directories are resolved; symlinks at or below the three roots are rejected.

    deploy-nvim-config.py <artifact-directory> <live-directory> <backup-directory>
"""
import os
from pathlib import Path
import shutil
import sys
import tempfile


def check_path(path, root, directory=False):
    while True:
        if path.is_symlink():
            raise ValueError(f"refusing symlink: {path}")
        if path.exists() and not (path.is_dir() if directory else path.is_file()):
            raise ValueError(f"unexpected file type: {path}")
        if path == root:
            break
        path = path.parent
        directory = True


def copy_atomic(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        shutil.copy2(source, temporary_path)
        os.replace(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def deploy(source, live, backup):
    roots = [Path(path).absolute() for path in (source, live, backup)]
    resolved = [root.resolve() for root in roots]
    for index, root in enumerate(resolved):
        for other in resolved[index + 1:]:
            if root.is_relative_to(other) or other.is_relative_to(root):
                raise ValueError("artifact, live, and backup directories must not overlap")
    for root in roots:
        check_path(root, root, directory=True)
    source, live, backup = resolved
    if not source.is_dir():
        raise ValueError(f"artifact directory not found: {source}")

    files = []
    for artifact in sorted(source.rglob("*")):
        if artifact.name == "lazy-lock.json":
            continue
        check_path(artifact, source, directory=artifact.is_dir())
        if artifact.is_file():
            relative = artifact.relative_to(source)
            destination = live / relative
            previous = backup / relative
            check_path(destination, live)
            check_path(previous, backup)
            files.append((artifact, destination, previous))

    installed = updated = 0
    for artifact, destination, previous in files:
        if destination.exists():
            if artifact.read_bytes() == destination.read_bytes():
                continue
            copy_atomic(destination, previous)
            updated += 1
        else:
            installed += 1
        copy_atomic(artifact, destination)
    print(f"Neovim config: {installed} installed, {updated} updated; backups: {backup}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__.strip())
    try:
        deploy(*sys.argv[1:])
    except (OSError, ValueError) as error:
        sys.exit(f"Neovim config: {error}")
