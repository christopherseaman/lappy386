# Sandbox Migration (retire `sqrlbot` → `dan`/Codex + Happier sandbox) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retarget the `dan` alias to run Codex locally, delete the `sqrlbot` provisioning, install Codex + Happier on hosts, and add disposable Codex+Happier sandboxes (Tart VM on macOS, rootless Podman on Linux).

**Architecture:** `lappy386` is a bash provisioning toolkit with no unit-test framework; validation is by execution and inspection (`bash -n`, behavioral stubs, real installs, container build/run, and documented manual checks for the Mac-only path). Two independent workstreams: (1) the trivial `dan` alias swap; (2) the sandbox migration (remove sqrlbot, install agents on host, add two `tools/sandbox/` provisioners).

**Tech Stack:** bash, Codex CLI (`curl … | sh`), Happier CLI (`curl … | bash`), rootless Podman + Debian container, Cirrus Labs Tart (Apple Silicon).

## Global Constraints

- Scripts use `#!/bin/bash` and must work on x86_64 and aarch64/arm64.
- Idempotent: guard installs/creation with `command -v` / existence checks (repo convention).
- Installs are **curl-to-shell, not npm** (both agents are Node-free):
  - Codex: `curl -fsSL https://chatgpt.com/codex/install.sh | sh`
  - Happier: `curl -fsSL https://happier.dev/install | bash`
- Codex bypass flag: `--dangerously-bypass-approvals-and-sandbox` (alias `--yolo`).
- Linux sandbox network: `--network=slirp4netns:allow_host_loopback=false`.
- macOS sandbox network isolation: `tart run --net-softnet`.
- Shared workspace is the host user's `~/projects`, mounted into the guest.
- Claude Code **stays** installed on the host (`setup-common.sh`); it is **not** installed in the sandbox (sandbox gets Codex + Happier only).
- **No teardown logic**: scripts stop *creating* `sqrlbot`; removing the existing user/ACLs on already-provisioned hosts is the operator's manual step.
- Commits: Conventional Commits, imperative, subject < 72 chars, **no Co-authored-by / attribution tags** (per user global rules).
- The spec of record is `sqrlbot_migration.md` at repo root.

---

### Task 1: Retarget the `dan` alias to Codex

**Files:**
- Modify: `tools/artifacts/dot-aliases:136-152` (the `dan()` function)
- Test: `/tmp/claude-1002/-home-christopher-projects-lappy386/4cc01452-4eed-4bea-8125-eb19e948ec8e/scratchpad/test-dan.sh` (throwaway)

**Interfaces:**
- Consumes: nothing.
- Produces: a `dan()` shell function that runs `codex --dangerously-bypass-approvals-and-sandbox "$@"`, or errors if `codex` is absent. No `sqrlbot`/`sudo` dependency.

- [ ] **Step 1: Write the failing behavioral test**

Create `…/scratchpad/test-dan.sh`:

```bash
#!/bin/bash
# Verifies dan() forwards args to codex with the bypass flag, and errors when codex is missing.
set -uo pipefail
ALIASES="/home/christopher/projects/lappy386/tools/artifacts/dot-aliases"
fail=0

# Case A: codex present -> dan forwards flag + args
tmp="$(mktemp -d)"
cat >"$tmp/codex" <<'EOF'
#!/bin/bash
echo "CODEX_CALLED $*"
EOF
chmod +x "$tmp/codex"
out="$(PATH="$tmp:$PATH" bash -c "source '$ALIASES'; dan hello world" 2>&1)"
if [[ "$out" == *"CODEX_CALLED --dangerously-bypass-approvals-and-sandbox hello world"* ]]; then
  echo "PASS: forwards flag + args"
else
  echo "FAIL: got: $out"; fail=1
fi

# Case B: codex missing -> dan errors non-zero and mentions codex
out="$(PATH="/nonexistent" bash -c "source '$ALIASES'; dan" 2>&1)"; rc=$?
if [[ $rc -ne 0 && "$out" == *codex* && "$out" != *sqrlbot* ]]; then
  echo "PASS: errors cleanly when codex missing"
else
  echo "FAIL: rc=$rc out: $out"; fail=1
fi

rm -rf "$tmp"
exit $fail
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash …/scratchpad/test-dan.sh`
Expected: FAIL — current `dan()` references `sqrlbot`/`sudo`, so Case A prints no `CODEX_CALLED` line and Case B mentions `sqrlbot`.

- [ ] **Step 3: Replace the `dan()` function**

In `tools/artifacts/dot-aliases`, replace lines 136–152 (the entire current `dan()` function) with:

```bash
dan() {
  command -v codex >/dev/null 2>&1 || {
    echo "dan: codex not installed (run tools/setup-common.sh)" >&2
    return 1
  }
  # DANgerous interactive agent: Codex with approvals + sandbox bypassed, as you.
  codex --dangerously-bypass-approvals-and-sandbox "$@"
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash …/scratchpad/test-dan.sh`
Expected: two `PASS` lines, exit 0.

- [ ] **Step 5: Syntax-check the file**

Run: `bash -n tools/artifacts/dot-aliases`
Expected: no output, exit 0.

- [ ] **Step 6: Commit**

```bash
git add tools/artifacts/dot-aliases
git commit -m "refactor: point dan alias at Codex, drop sqrlbot dependency"
```

---

### Task 2: Remove `sqrlbot` provisioning (no teardown)

**Files:**
- Delete: `tools/sqrlbot/setup-sqrlbot-common.sh`, `tools/sqrlbot/setup-sqrlbot-debian.sh`, `tools/sqrlbot/setup-sqrlbot-mac.sh` (the whole `tools/sqrlbot/` dir)
- Modify: `tools/setup-debian.sh:288-290` (remove the sqrlbot call)
- Modify: `tools/setup-macos.sh:54-56` (remove the sqrlbot call)
- Modify: `CLAUDE.md:22-23` (remove the `sqrlbot/` architecture-tree block)
- Modify: `.claude/settings.local.json` (remove two stale sqrlbot allow entries)

**Interfaces:**
- Consumes: nothing.
- Produces: a repo with no `sqrlbot` references except the spec `sqrlbot_migration.md`. `setup-debian.sh` / `setup-macos.sh` end after `./setup-common.sh`.

- [ ] **Step 1: Delete the creation scripts**

```bash
git rm tools/sqrlbot/setup-sqrlbot-common.sh tools/sqrlbot/setup-sqrlbot-debian.sh tools/sqrlbot/setup-sqrlbot-mac.sh
```

- [ ] **Step 2: Remove the sqrlbot call from `setup-debian.sh`**

In `tools/setup-debian.sh`, delete these trailing lines (288–290):

```bash

## SANDBOX USER (sqrlbot): create the jailed user + provision its Claude
./sqrlbot/setup-sqrlbot-debian.sh
```

The file must now end at line 287 (`./setup-common.sh`).

- [ ] **Step 3: Remove the sqrlbot call from `setup-macos.sh`**

In `tools/setup-macos.sh`, delete these trailing lines (54–56):

```bash

## SANDBOX USER (sqrlbot): create the jailed user + provision its Claude
./sqrlbot/setup-sqrlbot-mac.sh
```

The file must now end at line 53 (`./setup-common.sh`).

- [ ] **Step 4: Remove the `sqrlbot/` block from `CLAUDE.md`**

In `CLAUDE.md`, delete lines 22–23:

```
  sqrlbot/                  # Jailed sandbox user: setup-sqrlbot-{mac,debian}.sh create the
                            #   user + ACLs, then setup-sqrlbot-common.sh provisions its Claude
```

(Leave line 21 `setup-claude-mcp.sh …` and line 24 `artifacts/ …` intact and adjacent. The `tools/sandbox/` line is added in Task 6.)

- [ ] **Step 5: Remove stale sqrlbot allow entries from `.claude/settings.local.json`**

Replace the file's entire contents with:

```json
{
  "permissions": {
    "allow": [
      "Bash(xargs:*)",
      "Bash(done)"
    ]
  }
}
```

- [ ] **Step 6: Verify no sqrlbot references remain (except the spec) and scripts are valid**

```bash
grep -rn --exclude=sqrlbot_migration.md --exclude-dir=docs sqrlbot . ; echo "grep-rc=$?"
bash -n tools/setup-debian.sh tools/setup-macos.sh
python3 -c "import json; json.load(open('.claude/settings.local.json'))" && echo "json-ok"
```

Expected: the `grep` prints **no file matches** and `grep-rc=1` (no matches); `bash -n` prints nothing; `json-ok` prints.

- [ ] **Step 7: Commit**

```bash
git add -A tools/setup-debian.sh tools/setup-macos.sh CLAUDE.md .claude/settings.local.json
git commit -m "chore: remove sqrlbot provisioning scripts and wiring"
```

---

### Task 3: Install Codex + Happier on the host via `setup-common.sh`

**Files:**
- Modify: `tools/setup-common.sh:105-111` (replace the commented-out npm Happier stub)

**Interfaces:**
- Consumes: nothing.
- Produces: `setup-common.sh` installs/updates Codex and Happier (curl installers, idempotent guards) alongside the existing Claude install. Claude install (lines 98–104) is unchanged.

- [ ] **Step 1: Replace the commented Happier stub with active Codex + Happier installs**

In `tools/setup-common.sh`, replace lines 105–111 (the six commented `# HAPPIER_…` / `# npm i …` lines and the `# echo "Happier: …"` line) with:

```bash
if command -v codex &>/dev/null; then
  codex --version &>/dev/null || true
else
  echo "Codex: installing..."
  curl -fsSL https://chatgpt.com/codex/install.sh | sh &>/dev/null || true
fi
echo "Codex: $(codex --version 2>/dev/null | head -1 || true)"
if command -v happier &>/dev/null; then
  happier --version &>/dev/null || true
else
  echo "Happier: installing..."
  curl -fsSL https://happier.dev/install | bash &>/dev/null || true
fi
echo "Happier: $(happier --version 2>/dev/null | head -1 || true)"
```

(Leave the Claude block at 98–104 and the commented Copilot block at 91–97 untouched.)

- [ ] **Step 2: Syntax-check**

Run: `bash -n tools/setup-common.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Execute the install region on this host (real validation)**

Run the two installers directly (this is what the script does; it installs the agents you're migrating to):

```bash
command -v codex   || curl -fsSL https://chatgpt.com/codex/install.sh | sh
command -v happier || curl -fsSL https://happier.dev/install | bash
```

- [ ] **Step 4: Verify both binaries resolve**

Run: `bash -lc 'command -v codex && codex --version && command -v happier && happier --version'`
Expected: paths under `~/.local/bin` (or the installer's dir on `PATH`) and a version string for each. If `happier --version` fails (it is alpha), record the error — do not mark the task done until it resolves or the failure is understood.

- [ ] **Step 5: Commit**

```bash
git add tools/setup-common.sh
git commit -m "feat: install Codex and Happier CLIs in setup-common"
```

---

### Task 4: Linux sandbox — Containerfile + hardened run wrapper

**Files:**
- Create: `tools/sandbox/Containerfile`
- Create: `tools/sandbox/setup-sandbox-linux.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `setup-sandbox-linux.sh` builds `localhost/happier-agent:latest` (UID/GID = host user's) and runs it rootless with `--cap-drop=all --security-opt=no-new-privileges --network=slirp4netns:allow_host_loopback=false`, resource limits, and only `~/projects` + `~/.local/share/{codex,happier}-container` mounted. Run as the normal user (never sudo).

- [ ] **Step 1: Create the Containerfile**

Create `tools/sandbox/Containerfile`:

```dockerfile
# happier-agent — disposable Codex + Happier coding sandbox (Debian, Node-free base).
FROM debian:stable-slim

ARG UID=1000
ARG GID=1000

# Base tooling: curl (installers), git/ssh (repos), ca-certificates (TLS), and a build
# toolchain. Language toolchains (node, rust, …) are installed at runtime by the agent
# into its home and treated as disposable.
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates git openssh-client build-essential \
      python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Non-root agent user whose UID/GID match the host user, so rootless keep-id maps cleanly
# onto the bind-mounted workspace and persistent auth volumes.
RUN groupadd -g "${GID}" agent \
    && useradd -m -u "${UID}" -g "${GID}" -s /bin/bash agent

# Codex CLI — self-contained Rust binary. Install as root, copy onto the system PATH so the
# agent user can run it. `codex --version` fails the build if the copy path is wrong.
RUN curl -fsSL https://chatgpt.com/codex/install.sh | sh \
    && install -m 0755 "$(ls /root/.local/bin/codex 2>/dev/null || command -v codex)" /usr/local/bin/codex \
    && codex --version

# Happier CLI — self-contained. Same install-then-copy-onto-PATH pattern. `happier --version`
# fails the build if the candidate path is wrong (Happier is alpha; adjust the ls list here
# if the build fails at this step).
RUN curl -fsSL https://happier.dev/install | bash \
    && install -m 0755 "$(ls /root/.happier/bin/happier /root/.local/bin/happier 2>/dev/null | head -1 || command -v happier)" /usr/local/bin/happier \
    && happier --version

USER agent
WORKDIR /workspace
CMD ["/bin/bash"]
```

- [ ] **Step 2: Create the run wrapper**

Create `tools/sandbox/setup-sandbox-linux.sh`:

```bash
#!/bin/bash
# Build the happier-agent image and run a disposable Codex + Happier sandbox.
# Rootless Podman, started by the normal user (never sudo). The container's writable
# overlay layer is discarded on removal, so agent-installed toolchains stay disposable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="localhost/happier-agent:latest"
NAME="happier-agent"
WORKSPACE="${SANDBOX_WORKSPACE:-$HOME/projects}"
HAPPIER_STATE="$HOME/.local/share/happier-container"
CODEX_STATE="$HOME/.local/share/codex-container"

if ! command -v podman >/dev/null 2>&1; then
  echo "podman not found; installing..."
  sudo apt-get update && sudo apt-get install -y podman
fi

mkdir -p "$WORKSPACE" "$HAPPIER_STATE" "$CODEX_STATE"

# Build (idempotent; layer cache makes re-runs cheap). UID/GID baked in so keep-id maps clean.
podman build \
  --build-arg "UID=$(id -u)" \
  --build-arg "GID=$(id -g)" \
  -t "$IMAGE" \
  -f "$SCRIPT_DIR/Containerfile" \
  "$SCRIPT_DIR"

# Replace any previous instance.
podman rm -f "$NAME" >/dev/null 2>&1 || true

# Rootless, no new privileges, all caps dropped, resource-limited, cut off from host
# loopback services (slirp4netns). Only ~/projects + the two auth dirs are mounted.
exec podman run \
  --name "$NAME" \
  --hostname "$NAME" \
  --userns="keep-id:uid=$(id -u),gid=$(id -g)" \
  --cap-drop=all \
  --security-opt=no-new-privileges \
  --network=slirp4netns:allow_host_loopback=false \
  --memory=8g --pids-limit=512 --cpus=4 \
  --volume "$WORKSPACE:/workspace:rw" \
  --volume "$HAPPIER_STATE:/home/agent/.happier:rw" \
  --volume "$CODEX_STATE:/home/agent/.codex:rw" \
  --workdir /workspace \
  --interactive --tty \
  "$IMAGE" "$@"
```

- [ ] **Step 3: Make executable and syntax-check**

```bash
chmod +x tools/sandbox/setup-sandbox-linux.sh
bash -n tools/sandbox/setup-sandbox-linux.sh
```

Expected: no output.

- [ ] **Step 4: Build the image (real validation of the Containerfile)**

Run: `podman build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t localhost/happier-agent:latest -f tools/sandbox/Containerfile tools/sandbox`
Expected: build succeeds; the `codex --version` and `happier --version` RUN steps print versions. If the `happier` step fails, adjust the candidate `ls` paths in the Containerfile (Happier is alpha) and rebuild.

- [ ] **Step 5: Verify agents run + network policy inside the container**

```bash
# Agents present, running as the mapped non-root user:
podman run --rm --userns="keep-id:uid=$(id -u),gid=$(id -g)" \
  --network=slirp4netns:allow_host_loopback=false localhost/happier-agent:latest \
  bash -lc 'id -un; codex --version; happier --version; curl -sI --max-time 10 https://example.com | head -1'
```

Expected: prints `agent`, a Codex version, a Happier version, and an `HTTP/…` status line (public egress works).

- [ ] **Step 6: Manually confirm host-loopback isolation (documented check)**

In one terminal: `python3 -m http.server 8099 --bind 127.0.0.1`
In another: `podman run --rm --network=slirp4netns:allow_host_loopback=false localhost/happier-agent:latest bash -lc 'curl -s --max-time 3 http://host.containers.internal:8099 || echo BLOCKED'`
Expected: prints `BLOCKED` (the container cannot reach the host's loopback service). Stop the http.server afterward.

- [ ] **Step 7: Commit**

```bash
git add tools/sandbox/Containerfile tools/sandbox/setup-sandbox-linux.sh
git commit -m "feat: add rootless Podman Codex+Happier sandbox for Linux"
```

---

### Task 5: macOS sandbox — Tart provisioner

**Files:**
- Create: `tools/sandbox/setup-sandbox-mac.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `setup-sandbox-mac.sh` clones/configures the `macos-tahoe-xcode` Tart VM (idempotent), prints one-time guest bootstrap instructions, and runs it with `--net-softnet` LAN isolation and `~/projects` shared in.

- [ ] **Step 1: Create the script**

Create `tools/sandbox/setup-sandbox-mac.sh`:

```bash
#!/bin/bash
# Provision a disposable macOS + Xcode Tart VM running Codex + Happier, with ~/projects
# shared in and the guest isolated from the host LAN. Apple Silicon only.
set -euo pipefail

VM_NAME="${SANDBOX_VM:-tahoe-xcode}"
IMAGE="ghcr.io/cirruslabs/macos-tahoe-xcode:latest"
WORKSPACE="${SANDBOX_WORKSPACE:-$HOME/projects}"
CPU="${SANDBOX_CPU:-8}"
MEM_MB="${SANDBOX_MEM_MB:-16384}"
DISK_GB="${SANDBOX_DISK_GB:-150}"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "This sandbox requires macOS on Apple Silicon." >&2
  exit 1
fi

if ! command -v tart >/dev/null 2>&1; then
  echo "tart not found; installing via Homebrew..."
  brew install cirruslabs/cli/tart
fi

mkdir -p "$WORKSPACE"

# Clone the prebuilt Xcode image once (large, one-time). Idempotent: skip if VM exists.
if ! tart list --quiet 2>/dev/null | grep -qx "$VM_NAME"; then
  echo "Cloning $IMAGE -> $VM_NAME (large download, one-time)..."
  tart clone "$IMAGE" "$VM_NAME"
  tart set "$VM_NAME" --cpu "$CPU" --memory "$MEM_MB" --disk-size "$DISK_GB"
fi

cat <<EOF

Starting '$VM_NAME':
  LAN isolation:    --net-softnet
  Shared workspace: $WORKSPACE  ->  /Volumes/My Shared Files/projects (in guest)

One-time first-boot steps inside the guest (login admin/admin, then CHANGE the password):
  curl -fsSL https://chatgpt.com/codex/install.sh | sh
  curl -fsSL https://happier.dev/install | bash
  codex login
  happier auth login          # mobile-first; the daemon will not start until this completes
  happier daemon service install && happier daemon start

A Happier daemon error before auth completes is expected and benign.
EOF

exec tart run \
  --net-softnet \
  --dir="projects:$WORKSPACE" \
  "$VM_NAME"
```

- [ ] **Step 2: Make executable and syntax-check**

```bash
chmod +x tools/sandbox/setup-sandbox-mac.sh
bash -n tools/sandbox/setup-sandbox-mac.sh
```

Expected: no output. (Full run requires an Apple Silicon Mac — see Step 3.)

- [ ] **Step 3: Verify the non-Darwin guard on this Linux host**

Run: `bash tools/sandbox/setup-sandbox-mac.sh; echo "rc=$?"`
Expected: prints `This sandbox requires macOS on Apple Silicon.` and `rc=1`.

- [ ] **Step 4: Manual validation checklist (run on the Mac; cannot be automated here)**

Document these as the Mac acceptance steps (do not check the box until performed on the target Mac, or explicitly deferred by the user):
1. `./tools/sandbox/setup-sandbox-mac.sh` clones the VM (first run) and boots it.
2. In the guest, `/Volumes/My Shared Files/projects` shows the host's `~/projects`.
3. The two curl installers put `codex` and `happier` on PATH; `codex login` + `happier auth login` succeed.
4. From the guest, a LAN host (e.g. the router `192.168.x.1`) is unreachable, but public internet works (confirms `--net-softnet` isolation).

- [ ] **Step 5: Commit**

```bash
git add tools/sandbox/setup-sandbox-mac.sh
git commit -m "feat: add Tart macOS Codex+Happier sandbox provisioner"
```

---

### Task 6: Update `CLAUDE.md` architecture docs

**Files:**
- Modify: `CLAUDE.md:19` (setup-common.sh description) and `CLAUDE.md` architecture tree (add `tools/sandbox/`)

**Interfaces:**
- Consumes: the files created in Tasks 4–5 and the `dan`/agent changes.
- Produces: accurate architecture docs (no sqrlbot; documents `tools/sandbox/` and the `dan`=Codex local path).

- [ ] **Step 1: Update the `setup-common.sh` description**

In `CLAUDE.md`, change line 19 from:

```
  setup-common.sh           # Cross-platform: dotfiles, git, SSH, nvim config, nvm, Claude/Copilot CLI
```

to:

```
  setup-common.sh           # Cross-platform: dotfiles, git, SSH, nvim config, nvm, Claude/Codex/Happier CLIs
```

- [ ] **Step 2: Add the `tools/sandbox/` block to the architecture tree**

In `CLAUDE.md`, immediately after the `rdp/` line (currently line 30), add:

```
  sandbox/                  # Opt-in disposable agent sandboxes (run manually, not from setup.sh):
                            #   setup-sandbox-linux.sh (rootless Podman + Containerfile),
                            #   setup-sandbox-mac.sh (Tart macOS+Xcode VM). Run Codex via Happier.
```

- [ ] **Step 3: Document the `dan` local path**

In `CLAUDE.md`, under the `## Key Patterns` section, add this bullet (keep existing bullets):

```
- **Two ways agents run.** `dan` (in `artifacts/dot-aliases`) runs Codex locally in
  bypass mode, as you — supervised, no jail. For unattended/remote runs, `tools/sandbox/`
  provides a disposable VM/container fronted by Happier. See `sqrlbot_migration.md`.
```

- [ ] **Step 4: Verify no sqrlbot references and Markdown reads cleanly**

```bash
grep -n sqrlbot CLAUDE.md; echo "rc=$?"
```

Expected: no matches, `rc=1`.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document tools/sandbox and dan Codex path in CLAUDE.md"
```

---

## Self-Review

**Spec coverage** (against `sqrlbot_migration.md`):
- Change 1 (`dan` → Codex bypass, as you) → Task 1. ✓
- Delete sqrlbot creation scripts + wiring (`setup-debian.sh`, `setup-macos.sh`, `CLAUDE.md`, `settings.local.json`), no teardown → Task 2. ✓
- Codex + Happier via curl on host, keep Claude → Task 3. ✓
- Linux sandbox: rootless Podman, cap-drop/no-new-privs, keep-id scoped, resource limits, `slirp4netns:allow_host_loopback=false`, only `~/projects` + auth dirs mounted, Node-free curl installs → Task 4. ✓
- macOS sandbox: Tart macOS+Xcode guest, `--net-softnet`, virtiofs `~/projects`, curl installs, Happier daemon-fails-until-auth note → Task 5. ✓
- Docs (tools/sandbox, dan) → Task 6. ✓
- Auth model (Happier Cloud, Codex in-guest via `codex login`, persistent volumes) → covered by the guest bootstrap in Tasks 4–5 (persistent volumes) and the printed login steps. ✓

**Deviations from spec (flagged for user):**
1. **`--read-only` root dropped** for the Linux container (Task 4). A coding agent must write toolchains/caches to build; the container's ephemeral writable layer already provides disposability. Other hardening (cap-drop, no-new-privs, limits, network, keep-id, no socket mounts) is retained. If strict `--read-only` is required, add it back with writable `--tmpfs`/volumes for `/tmp`, `/home/agent`, and caches.
2. Container UID/GID are `--build-arg`-parameterized to the host user (not hardcoded 1000) so rootless `keep-id` maps cleanly — a refinement over the spec's illustrative `uid=1000`.

**Placeholder scan:** No TBD/TODO. The two externally-uncertain install paths (Codex/Happier binary locations in the Containerfile) are handled by build-time `--version` assertions that fail loudly, with a documented adjustment point — not silent placeholders.

**Type/name consistency:** image `localhost/happier-agent:latest`, container `happier-agent`, state dirs `~/.local/share/{happier,codex}-container`, and mount paths `/home/agent/.{happier,codex}` are consistent across the Containerfile, run wrapper, and spec.
