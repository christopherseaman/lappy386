#!/usr/bin/env python3
"""Overlay a canonical JSON settings artifact onto a live settings file.

Top-level keys from the artifact win; keys present only in the live file are
preserved. A plain `cp artifact live` drops app-written keys (Claude Code writes
some itself, e.g. skipWorkflowUsageWarning) and machine-local preferences.

Nested objects are replaced wholesale rather than deep-merged, so removing an
entry from the artifact removes it on the next run.

    merge-settings.py <artifact.json> <live.json>
"""
import json
import os
import shutil
import stat
import sys


def load(path):
    """Parse a settings file, refusing to proceed rather than crashing on bad input."""
    try:
        with open(path) as f:
            value = json.load(f)
    except json.JSONDecodeError as e:
        sys.exit(f"error: {path} is not valid JSON, refusing to edit: {e}")
    if not isinstance(value, dict):
        sys.exit(f"error: {path} is not a JSON object, refusing to edit")
    return value


def merge(artifact_path, live_path):
    artifact = load(artifact_path)
    live = load(live_path) if os.path.exists(live_path) else {}

    merged = dict(live)
    merged.update(artifact)

    if merged == live:
        print("Claude settings: already current")
        return 0

    mode = 0o600
    if os.path.exists(live_path):
        mode = stat.S_IMODE(os.stat(live_path).st_mode)
        backup = live_path + ".bak"
        if not os.path.exists(backup):
            shutil.copy2(live_path, backup)

    os.makedirs(os.path.dirname(live_path) or ".", exist_ok=True)
    tmp = live_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")
    os.chmod(tmp, mode)
    os.replace(tmp, live_path)

    added = sorted(k for k in artifact if k not in live)
    changed = sorted(k for k in artifact if k in live and live[k] != artifact[k])
    kept = sorted(k for k in live if k not in artifact)
    print(
        "Claude settings: "
        f"{len(added)} added, {len(changed)} updated, {len(kept)} preserved"
    )
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(2)
    sys.exit(merge(sys.argv[1], sys.argv[2]))
