# Linux Sandbox Workspace ACLs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure the Linux sandbox workspace root with deterministic group-writable access and inherited POSIX ACLs before Podman mutates container state.

**Architecture:** Keep orchestration in the existing Linux setup script. Add one dependency-free shell regression test that executes the real script while replacing only external system operations with isolated command stubs, so ACL arguments and ordering are verified without building an image or replacing a container.

**Tech Stack:** Bash, POSIX ACL tools (`setfacl`), coreutils, rootless Podman command interface.

## Global Constraints

- Apply the change only to `tools/sandbox/setup-sandbox-linux.sh`; leave the macOS Tart workflow unchanged.
- Resolve the workspace group from `SANDBOX_WORKSPACE_GROUP`, defaulting to `id -gn`.
- Treat a missing `setfacl` command as a hard preflight failure; do not install the ACL package automatically.
- Reset access and default ACLs only on the workspace root; never recurse into existing descendants.
- Perform ACL setup after workspace creation and before image build or container replacement.
- Preserve the repository's existing `set -euo pipefail` failure behavior.
- Preserve unrelated worktree changes, including `tools/artifacts/ghostty.config`.

---

### Task 1: Enforce Linux workspace ACLs

**Files:**
- Create: `tests/sandbox/setup-sandbox-linux-test.sh`
- Modify: `tools/sandbox/setup-sandbox-linux.sh:12-27`

**Interfaces:**
- Consumes: `SANDBOX_WORKSPACE`, optional `SANDBOX_WORKSPACE_GROUP`, `id -gn`, and the host commands `chgrp`, `chmod`, and `setfacl`.
- Produces: a workspace root owned by the selected group, mode `2770`, access ACL `u::rwx,g::rwx,m::rwx,o::---`, and the same default ACL; exits nonzero before Podman operations if `setfacl` or an ACL operation fails.

- [ ] **Step 1: Write the failing shell regression test**

Create `tests/sandbox/setup-sandbox-linux-test.sh` with this content:

```bash
#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/tools/sandbox/setup-sandbox-linux.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_fake_bin() {
  local fake_bin="$1"
  mkdir -p "$fake_bin"

  cat > "$fake_bin/stub" <<'EOF'
#!/bin/bash
set -euo pipefail

command_name="${0##*/}"
case "$command_name" in
  id)
    case "${1:-}" in
      -gn) echo "sandboxers" ;;
      -u|-g) echo "1000" ;;
      *) exit 2 ;;
    esac
    ;;
  hostname)
    echo "test-host"
    ;;
  chgrp|chmod|podman|setfacl|uv)
    printf '%s' "$command_name" >> "$CALL_LOG"
    printf ' %q' "$@" >> "$CALL_LOG"
    printf '\n' >> "$CALL_LOG"
    ;;
  *)
    echo "Unexpected stub command: $command_name" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "$fake_bin/stub"

  ln -s "$(command -v dirname)" "$fake_bin/dirname"
  ln -s "$(command -v mkdir)" "$fake_bin/mkdir"
  local command_name
  for command_name in id hostname podman uv chgrp chmod; do
    ln -s stub "$fake_bin/$command_name"
  done
}

run_setup() {
  local fake_bin="$1"
  local test_home="$2"
  local workspace="$3"
  local call_log="$4"
  local workspace_group="${5:-}"

  if [[ -n "$workspace_group" ]]; then
    CALL_LOG="$call_log" \
      PATH="$fake_bin" \
      HOME="$test_home" \
      SANDBOX_WORKSPACE="$workspace" \
      SANDBOX_WORKSPACE_GROUP="$workspace_group" \
      /bin/bash "$SCRIPT"
  else
    CALL_LOG="$call_log" \
      PATH="$fake_bin" \
      HOME="$test_home" \
      SANDBOX_WORKSPACE="$workspace" \
      /bin/bash "$SCRIPT"
  fi
}

assert_acl_prefix() {
  local call_log="$1"
  local workspace="$2"
  local expected_group="$3"
  local actual expected

  actual="$(sed -n '1,7p' "$call_log")"
  expected="$(printf '%s\n' \
    "chgrp $expected_group $workspace" \
    "setfacl -b $workspace" \
    "setfacl -k $workspace" \
    "chmod 2770 $workspace" \
    "setfacl -m u::rwx,g::rwx,m::rwx,o::--- $workspace" \
    "setfacl -d -m u::rwx,g::rwx,m::rwx,o::--- $workspace" \
    "podman build --build-arg UID=1000 --build-arg GID=1000 -t localhost/agent:latest -f $REPO_ROOT/tools/sandbox/Containerfile $REPO_ROOT/tools/sandbox/..")"

  [[ "$actual" == "$expected" ]] || fail "unexpected ACL/setup command order:\n$actual"
}

test_missing_setfacl_fails_before_podman() {
  local case_root="$TEST_ROOT/missing-setfacl"
  local fake_bin="$case_root/bin"
  local call_log="$case_root/calls.log"
  mkdir -p "$case_root/home"
  : > "$call_log"
  make_fake_bin "$fake_bin"

  local output
  if output="$(run_setup "$fake_bin" "$case_root/home" "$case_root/workspace" "$call_log" 2>&1)"; then
    fail "setup succeeded without setfacl"
  fi
  [[ "$output" == *"setfacl is required to configure group-writable workspace ACLs."* ]] \
    || fail "missing setfacl error was not reported"
  [[ ! -s "$call_log" ]] || fail "an external mutation ran before the setfacl preflight"
}

test_default_group_configures_acl_before_podman() {
  local case_root="$TEST_ROOT/default-group"
  local fake_bin="$case_root/bin"
  local call_log="$case_root/calls.log"
  mkdir -p "$case_root/home"
  : > "$call_log"
  make_fake_bin "$fake_bin"
  ln -s stub "$fake_bin/setfacl"

  run_setup "$fake_bin" "$case_root/home" "$case_root/workspace" "$call_log"
  assert_acl_prefix "$call_log" "$case_root/workspace" "sandboxers"
}

test_group_override_is_used() {
  local case_root="$TEST_ROOT/group-override"
  local fake_bin="$case_root/bin"
  local call_log="$case_root/calls.log"
  mkdir -p "$case_root/home"
  : > "$call_log"
  make_fake_bin "$fake_bin"
  ln -s stub "$fake_bin/setfacl"

  run_setup "$fake_bin" "$case_root/home" "$case_root/workspace" "$call_log" \
    "collaborators"
  assert_acl_prefix "$call_log" "$case_root/workspace" "collaborators"
}

test_missing_setfacl_fails_before_podman
test_default_group_configures_acl_before_podman
test_group_override_is_used
echo "PASS: setup-sandbox-linux workspace ACL tests"
```

The test catches these production regressions: removing the dependency preflight, resolving the wrong group, omitting or reordering an ACL command, changing an ACL argument, or beginning the Podman build before permissions are configured. The script under test remains real; stubs replace only host-mutating or external operations.

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
bash tests/sandbox/setup-sandbox-linux-test.sh
```

Expected: FAIL with `setup succeeded without setfacl`, because the production script does not yet require or invoke `setfacl`.

- [ ] **Step 3: Implement the minimal ACL setup**

In `tools/sandbox/setup-sandbox-linux.sh`, define the group beside `WORKSPACE`:

```bash
WORKSPACE="${SANDBOX_WORKSPACE:-$HOME/projects}"
WORKSPACE_GROUP="${SANDBOX_WORKSPACE_GROUP:-$(id -gn)}"
```

Immediately after the existing `mkdir -p "$WORKSPACE" "$CODEX_STATE" "$GH_STATE"`, add:

```bash
if ! command -v setfacl >/dev/null 2>&1; then
  echo "setfacl is required to configure group-writable workspace ACLs." >&2
  exit 1
fi

chgrp "$WORKSPACE_GROUP" "$WORKSPACE"
setfacl -b "$WORKSPACE"
setfacl -k "$WORKSPACE"
chmod 2770 "$WORKSPACE"
setfacl -m "u::rwx,g::rwx,m::rwx,o::---" "$WORKSPACE"
setfacl -d -m "u::rwx,g::rwx,m::rwx,o::---" "$WORKSPACE"
```

- [ ] **Step 4: Run the regression test and verify GREEN**

Run:

```bash
bash tests/sandbox/setup-sandbox-linux-test.sh
```

Expected: `PASS: setup-sandbox-linux workspace ACL tests` and exit status 0.

- [ ] **Step 5: Run static shell validation**

Run:

```bash
bash -n tools/sandbox/setup-sandbox-linux.sh
bash -n tests/sandbox/setup-sandbox-linux-test.sh
git diff --check
```

Expected: all commands exit 0 with no output. If `shellcheck` is already installed, also run:

```bash
shellcheck tools/sandbox/setup-sandbox-linux.sh tests/sandbox/setup-sandbox-linux-test.sh
```

Expected: exit status 0. Do not install a new dependency solely for this check.

- [ ] **Step 6: Verify real ACL behavior when a suitable Linux host is available**

Run only on Linux with `setfacl`, `getfacl`, and an ACL-capable temporary filesystem:

```bash
acl_test_dir="$(mktemp -d)"
chgrp "$(id -gn)" "$acl_test_dir"
setfacl -b "$acl_test_dir"
setfacl -k "$acl_test_dir"
chmod 2770 "$acl_test_dir"
setfacl -m "u::rwx,g::rwx,m::rwx,o::---" "$acl_test_dir"
setfacl -d -m "u::rwx,g::rwx,m::rwx,o::---" "$acl_test_dir"
stat -c '%a %G' "$acl_test_dir"
getfacl -cp "$acl_test_dir"
rmdir "$acl_test_dir"
```

Expected: `stat` reports mode `2770` and the invoking user's primary group. `getfacl` reports access and default entries `user::rwx`, `group::rwx`, `mask::rwx`, and `other::---`. If the current environment is not suitable, record this verification as pending rather than treating substitute evidence as complete.

- [ ] **Step 7: Commit the implementation**

```bash
git add tools/sandbox/setup-sandbox-linux.sh tests/sandbox/setup-sandbox-linux-test.sh
git commit -m "fix: configure Linux sandbox workspace ACLs"
```
