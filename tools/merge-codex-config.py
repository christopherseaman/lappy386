#!/usr/bin/env python3
"""Apply this repo's managed codex settings to a config.toml, preserving everything else.

    merge-codex-config.py {host|sandbox} <config.toml>

Scope is an argument, not a key list: callers cannot name keys, so the permissive
sandbox pair (approval_policy / sandbox_mode) is unreachable from the host scope.
Those two belong only in the container, which is itself the jail; on an unjailed
host they would remove the approval gate entirely.

codex co-owns this file — it writes [projects.*] trust levels and [apps.*] approval
entries during normal use. Only top-level keys in the preamble (everything before the
first table header) are rewritten; the table section is copied through byte for byte.

Stdlib only, matching merge-settings.py: tomllib reads TOML but cannot write it, and a
third-party writer would add a network fetch to provisioning. Correctness is enforced by
re-parsing the result and diffing it against the input rather than by trusting the edit.
"""
import os
import re
import stat
import sys
import tomllib

MANAGED = {
    "host": {
        "personality": "pragmatic",
        "model": "gpt-5.6-sol",
        "model_reasoning_effort": "xhigh",
    },
    "sandbox": {
        "personality": "pragmatic",
        "model": "gpt-5.6-sol",
        "model_reasoning_effort": "xhigh",
        # Only ever correct inside the container.
        "approval_policy": "never",
        "sandbox_mode": "danger-full-access",
    },
}

TABLE_START = re.compile(r"^\s*\[")
MAX_MODE = 0o600


def split_preamble(text):
    """Return (preamble_lines, table_lines). Top-level keys live in the preamble."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if TABLE_START.match(line):
            return lines[:i], lines[i:]
    return lines, []


def apply(preamble, managed):
    """Rewrite existing assignments in place; append the rest before any tables."""
    out, seen = [], set()
    for line in preamble:
        for key, value in managed.items():
            if re.match(rf"^\s*{re.escape(key)}\s*=", line):
                out.append(f'{key} = "{value}"')
                seen.add(key)
                break
        else:
            out.append(line)
    for key, value in managed.items():
        if key not in seen:
            out.append(f'{key} = "{value}"')
    return out


def render(preamble, tables):
    body = [ln for ln in preamble if ln.strip()]
    if tables:
        return "\n".join(body + [""] + tables) + "\n"
    return "\n".join(body) + "\n"


def main(scope, path):
    if scope not in MANAGED:
        sys.exit(f"error: scope must be one of {', '.join(MANAGED)}, got {scope!r}")
    managed = MANAGED[scope]

    # Follow symlinks so the real file is edited, not replaced by a regular file.
    path = os.path.realpath(os.path.expanduser(path))

    original = ""
    before = {}
    if os.path.exists(path):
        with open(path, "rb") as f:
            original = f.read().decode()
        try:
            before = tomllib.loads(original)
        except tomllib.TOMLDecodeError as e:
            sys.exit(f"error: {path} is not valid TOML, refusing to edit: {e}")

    preamble, tables = split_preamble(original)
    updated = render(apply(preamble, managed), tables)

    if updated == original:
        print(f"Codex config ({scope}): already current")
        return 0

    # Trust the diff, not the edit: the result must be the input plus exactly the
    # managed keys. Anything else means the rewrite corrupted something.
    try:
        after = tomllib.loads(updated)
    except tomllib.TOMLDecodeError as e:
        sys.exit(f"error: edit produced invalid TOML, aborting: {e}")
    expected = dict(before)
    expected.update(managed)
    if after != expected:
        lost = sorted(set(before) - set(after))
        sys.exit(
            "error: edit would change unmanaged content, aborting"
            + (f" (lost: {', '.join(lost)})" if lost else "")
        )

    # Never widen permissions: config.toml sits beside auth.json.
    mode = MAX_MODE
    if os.path.exists(path):
        mode = stat.S_IMODE(os.stat(path).st_mode) & MAX_MODE

    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    with os.fdopen(fd, "w") as f:
        f.write(updated)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)

    added = sorted(k for k in managed if k not in before)
    changed = sorted(k for k in managed if k in before and before[k] != managed[k])
    kept = sorted(k for k in before if k not in managed)
    print(
        f"Codex config ({scope}): {len(added)} added, {len(changed)} updated, "
        f"{len(kept)} preserved"
    )
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: merge-codex-config.py {host|sandbox} <config.toml>")
    sys.exit(main(sys.argv[1], sys.argv[2]))
