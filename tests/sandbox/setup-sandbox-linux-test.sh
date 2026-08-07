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
    printf ' <%s>' "$@" >> "$CALL_LOG"
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
    "chgrp <$expected_group> <$workspace>" \
    "setfacl <-b> <$workspace>" \
    "setfacl <-k> <$workspace>" \
    "chmod <2770> <$workspace>" \
    "setfacl <-m> <u::rwx,g::rwx,m::rwx,o::---> <$workspace>" \
    "setfacl <-d> <-m> <u::rwx,g::rwx,m::rwx,o::---> <$workspace>" \
    "podman <build> <--build-arg> <UID=1000> <--build-arg> <GID=1000> <-t> <localhost/agent:latest> <-f> <$REPO_ROOT/tools/sandbox/Containerfile> <$REPO_ROOT/tools/sandbox/..>")"

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
