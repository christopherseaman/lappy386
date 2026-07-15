# Sandboxing Coding Agents — Retiring `sqrlbot`

Retiring the `sqrlbot` jail produces **two independent changes**. They share a cause but
are otherwise unrelated and can land separately:

1. **The `dan` alias** is simply retargeted — away from "run Claude as the jailed
   `sqrlbot` user" to "run Codex locally, as you." Small and self-contained
   (see Change 1).
2. **The autonomous-run sandbox** is the actual migration: replace the `sqrlbot`
   OS-user jail with a **disposable, Happier-fronted sandbox** — a Tart VM on macOS, a
   rootless Podman container on Linux (see Change 2). This is the bulk of the doc.

The agent is migrating from Claude Code to **Codex**. Codex's remote/mobile tooling is
weaker than Claude Code's, which is why the sandbox is fronted by **Happier** (a
cross-device client + encrypted relay for coding-agent CLIs). Happier is the control
surface, **not** the sandbox itself — it rides on top of whatever boundary the guest
provides.

## Why `sqrlbot` goes away

The old model ran Claude as a jailed, **non-admin** OS user (`sqrlbot`) with
`--dangerously-skip-permissions`. That jail is the source of the recurring macOS pain:
a non-admin user cannot use the admin's Homebrew prefix (`brew` refuses to run when it
doesn't own `/opt/homebrew`), the sandbox user was given no toolchain or `brew` PATH of
its own, and the macOS OAuth store needed an empty-password login-keychain shim. All of
that disappears when local runs happen **as you** (the `dan` alias) and unattended runs
happen **inside a VM/container** (the sandbox). No jailed-but-local middle ground
remains.

## Non-goals

- Perfect containment. This substantially reduces blast radius; it does not stop an
  agent from misusing whatever is inside `~/projects` or exfiltrating it over the
  internet.
- A single identical mechanism on both platforms. macOS needs a VM (you cannot cheaply
  namespace-sandbox macOS, and Xcode builds require a macOS guest); Linux uses a
  container. The **pattern** is unified ("agent runs in a disposable sandbox"); the
  mechanism is platform-appropriate.

---

## Change 1 — the `dan` alias (separate, small)

This is independent of the sandbox work below — just an alias swap in
`tools/artifacts/dot-aliases`, with no dependency on Change 2. It only exists here
because retiring `sqrlbot` is what removes the alias's old target.

`dan` reverts to what the name implies: a one-word launcher for a **DAN**gerous
interactive Codex session, running as you, in the current directory.

```bash
# dan — DANgerous interactive agent: Codex with approvals + sandbox bypassed, as you.
dan() {
  command -v codex >/dev/null 2>&1 || {
    echo "dan: codex not installed (run tools/setup-common.sh)" >&2
    return 1
  }
  codex --dangerously-bypass-approvals-and-sandbox "$@"
}
```

Notes:
- `--dangerously-bypass-approvals-and-sandbox` (shorthand `--yolo`) is the verified
  current Codex flag for full bypass. Re-confirm against the installed version at
  implementation time — Codex flags have moved across releases.
- No `sudo`, no `sqrlbot`, no keychain shim. Codex uses your normal toolchain and your
  own `~/.codex` auth. The safety story for `dan` is *supervision*, not confinement.

---

## Change 2 — the autonomous-run sandbox (Happier + disposable guest)

Shared principles across both platforms:

- Only **Codex** and the **Happier daemon** are installed **inside** the guest (not
  Claude Code). Both install Node-free via their `curl` installers (shown below). You
  drive them from the Happier app; the agent never runs on the host.
- Only `~/projects` is shared into the guest (read/write). Nothing else from `$HOME`.
- Toolchains, dependency caches, and build output live **inside** the guest and are
  treated as disposable. Only source and intentionally-tracked files live in the share.
- **Egress filtering is enforced with a tool-native mechanism, not the host firewall**
  (see Network restrictions — this is the key correction to the earlier draft).

### Security boundary

The guest **may** access:

- `~/projects`
- Public internet (docs, package registries, model-provider APIs, public app APIs)
- Repository-scoped Git credentials (if you choose to provision them in-guest)

The guest **must not** access:

- The rest of the host home directory
- Host SSH agents / keychains
- Cloud-provider credentials
- Docker / Podman sockets
- Host local servers and services
- Private LAN address ranges
- Host administrative privileges

### macOS → Tart VM (macOS + Xcode guest)

Tart runs macOS VMs on Apple Silicon from prebuilt Xcode images. **Tart is now free**
for this use (Cirrus Labs joined OpenAI in April 2026 and dropped licensing fees;
LICENSE is FSL-1.1-ALv2 → Apache-2.0 after two years — ignore the stale pricing page).

```bash
brew install cirruslabs/cli/tart

tart clone ghcr.io/cirruslabs/macos-tahoe-xcode:latest tahoe-xcode
tart set  tahoe-xcode --cpu 8 --memory 16384 --disk-size 150

# --net-softnet: isolate the guest from the host LAN while keeping public internet
tart run \
  --net-softnet \
  --dir=projects:"$HOME/projects" \
  tahoe-xcode
```

- Shared dir appears in the guest at `/Volumes/My Shared Files/projects` (virtiofs).
- Default image credentials are `admin` / `admin` — **change them** before the VM is
  reachable on any network beyond the host.
- **Host spec:** this is a full macOS-in-macOS VM. Budget **≥32 GB host RAM** and
  **≥150 GB free disk** (Xcode + Simulator runtimes + DerivedData grow to 60–100+ GB).
- **Keep caches in-guest** (`DerivedData`, `~/Library/Caches`, `~/.npm`, `~/.cargo`).
  This is not just tidiness: Apple-Virtualization-framework virtiofs is slow for
  metadata-heavy small-file I/O (`git status` on a big repo, `node_modules`,
  CocoaPods), so keeping build trees out of the share avoids the worst pathology.

Guest bootstrap (one-time): confirm Xcode (`xcodebuild -version`, accept license /
`xcodebuild -runFirstLaunch` if needed), then install and bring up the agent stack:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh    # Codex (self-contained, no Node)
curl -fsSL https://happier.dev/install | bash           # Happier CLI (self-contained)
codex login                                             # interactive, once
happier auth login                                      # interactive, once (Happier Cloud)
happier daemon service install && happier daemon start  # run the daemon headless
```

The daemon won't come up until `happier auth login` is fully complete (auth is
mobile-first) — a pre-auth daemon error here is **expected and benign**, not something to
retry-loop or abort on. Then preserve the VM rather than recreating it.

Note: the Tart VM **isolates** the Homebrew/build-permission problem rather than fixing
it — it's the same Homebrew, but in a disposable single-user guest you can throw away
when its state rots. That disposability is the actual win.

### Linux → rootless Podman

Rootless Podman, started by the normal host user (never `sudo`).

```bash
sudo apt-get update && sudo apt-get -y install podman
podman info   # verify rootless

podman run \
  --name happier-agent \
  --hostname happier-agent \
  --userns=keep-id:uid=1000,gid=1000 \   # scope the map; do NOT map the full range
  --cap-drop=all \
  --security-opt=no-new-privileges \
  --network=slirp4netns:allow_host_loopback=false \   # block the host's loopback services
  --read-only --tmpfs /tmp \
  --memory=8g --pids-limit=512 --cpus=4 \
  --volume "$HOME/projects:/workspace:rw" \
  --volume "$HOME/.local/share/happier-container:/home/agent/.happier:rw" \
  --volume "$HOME/.local/share/codex-container:/home/agent/.codex:rw" \
  --workdir /workspace \
  localhost/happier-agent:latest
```

Never mount: `$HOME`, `$HOME/.ssh`, `$HOME/.config`, `$HOME/.aws`, `$HOME/.kube`,
`/run/podman/podman.sock`, `/var/run/docker.sock`.

Hardening rationale (additions over the original draft):
- `--read-only --tmpfs /tmp`, `--memory`, `--pids-limit`, `--cpus`: contain a
  runaway/forking agent (OOM, fork-bomb) that the bare draft left unbounded.
- `--userns=keep-id:uid=,gid=` scopes the UID/GID map instead of mapping the full
  0–65535 range. Full-range `keep-id` maps `overflowuid` (effectively host root) into
  the namespace and runs the container as your real host UID — a breakout would then
  have your UID's reach. Scope it, or use chowned volumes.
- The mounted `.happier` / `.codex` volumes hold live auth tokens the agent can read.
  That is consistent with the threat model (exfiltration is already conceded), but is
  the reason nothing else from `$HOME` is mounted.

---

## Network restrictions

Allow ordinary outbound internet (docs, GitHub, package downloads, model APIs, public
app APIs). Block private / local ranges:

```
10.0.0.0/8   172.16.0.0/12   192.168.0.0/16
127.0.0.0/8  169.254.0.0/16
::1/128      fc00::/7        fe80::/10
```

**Enforcement point differs per platform — do NOT rely on the host firewall for the
Linux path.** This is the central correction to the earlier draft.

- **macOS / Tart:** the VM has a real NAT interface, and **`--net-softnet`** provides
  guest-from-LAN isolation directly. Host `pf` on the vmnet interface is also a valid
  enforcement point if finer control is wanted. Host-level rules genuinely apply here.
- **Linux / rootless Podman:** host `iptables`/`nftables` **cannot** filter
  rootless-Podman egress per-container. The default `pasta` (and `slirp4netns`)
  backends re-originate container traffic as ordinary sockets from a host-side process
  running as your UID, so it traverses the host **OUTPUT** path, not FORWARD, with the
  container's identity erased. A FORWARD rule catches nothing; an OUTPUT rule would also
  cut off *your own* host's LAN access. Enforcement is therefore **in the network
  backend**, not the host firewall. **Chosen:
  `--network=slirp4netns:allow_host_loopback=false`** — cuts the container off from the
  host's own loopback services. Accepted tradeoff: **LAN peers on the same subnet stay
  reachable** (this backend blocks host services, not sibling machines). If strict
  LAN-peer blocking is ever required, the fallback is `--network=none` + a host egress
  proxy that denies RFC1918, pointed at via `HTTPS_PROXY`/`HTTP_PROXY`.

The `169.254.169.254` / `fd00:ec2::254` **cloud metadata** endpoints are irrelevant on
a personal (non-cloud) host — there is no IMDS to reach. The `169.254.0.0/16` block
above covers them as harmless defense-in-depth; do not treat them as load-bearing here.

---

## Auth / credentials

- **Happier** uses **Happier Cloud** (the hosted relay), via `happier auth login`. Trust
  implication to accept: session content is end-to-end encrypted, but **service tokens
  (your OpenAI/GitHub creds) are stored server-side encrypted, not E2E**, so on Happier
  Cloud that trust sits with the operators. Happier is **pre-release/alpha** — treat as
  beta and re-verify daemon subcommands at build time.
- **The Happier daemon is expected to fail until auth is complete.** `happier auth login`
  is a one-time, mobile-first manual step; until it finishes, the daemon won't come up.
  Provisioning must treat a pre-auth daemon error as **benign, not fatal** — do not
  retry-loop or abort on it (same "auth is a one-time manual step" principle as the old
  sqrlbot login).
- **Codex** authenticates in-guest (`codex login` or `OPENAI_API_KEY`); creds live in
  the guest's `~/.codex`, mounted as a persistent volume so they survive rebuilds.
  Credentials are never copied from the host — auth is a one-time manual step per guest,
  same principle as the old setup.

## Persistence model

Persist: the Tart VM disk; Happier config; Codex auth state; language toolchains and
caches; Xcode/Simulator runtimes; the Podman named volumes for `.happier`/`.codex`.

Disposable: build outputs; temporary worktrees; downloaded dependencies; agent-created
branches; the container's writable layer.

## Operational workflow

**`dan` (local):** `cd` into a project, type `dan [prompt]`, watch it work, review the
diff in your own account.

**Sandbox (remote):**
1. Start the sandbox (Tart VM on macOS / Podman container on Linux).
2. `~/projects` is mounted in; the Happier daemon is running inside.
3. Connect from iOS / iPadOS / desktop / web via Happier; run Codex through it.
4. Review Git diffs before merging.
5. Stop the guest when done; rebuild/restore it if its state becomes questionable.

## Threat-model limitations

Does not prevent an agent from: reading/modifying every repo in `~/projects`;
exfiltrating repository contents; introducing malicious code; downloading/executing
compromised dependencies; deleting uncommitted files in the workspace.

Does substantially reduce the chance an agent can: modify arbitrary host files outside
the share; access personal host credentials; reach local infrastructure; run as host
admin; persist via host services; control unrelated containers/VMs.

Isolation strength is **not equal across platforms**: Tart is a true VM boundary
(separate guest kernel — a kernel escape is needed); rootless Podman shares the host
kernel (a kernel/namespace/seccomp bug is a host compromise), and `keep-id` narrows the
UID separation. macOS is the stronger boundary; Linux is lighter and more disposable.

---

## Changes to this repo (lappy386)

**Delete from the repo** (stop provisioning `sqrlbot` going forward — no teardown logic):
- `tools/sqrlbot/` (all three creation scripts).
- The `./sqrlbot/setup-sqrlbot-*.sh` calls in `tools/setup-debian.sh` and
  `tools/setup-macos.sh`.
- The `sqrlbot/` documentation block in `CLAUDE.md`.
- Any incidental `sqrlbot` permission entries in `.claude/settings.local.json`.

> The scripts only stop *creating* `sqrlbot`. Removing the already-created `sqrlbot`
> user, its group, and the `~/projects` ACLs on machines already provisioned is a
> **manual, operator-side step** — the toolkit does not (and should not) automate
> user teardown. Re-running `setup.sh` after this change simply leaves the orphaned
> user untouched until you remove it by hand.

**Rewrite:**
- The `dan()` function in `tools/artifacts/dot-aliases` → the local Codex launcher above.

**Add:**
- `tools/sandbox/setup-sandbox-mac.sh` — Tart clone/config (`--net-softnet`, virtiofs
  `~/projects`), guest bootstrap installing Codex + Happier via their `curl` installers.
- `tools/sandbox/setup-sandbox-linux.sh` — a `Containerfile` for the `happier-agent`
  image (Debian + `curl`-installed Codex + Happier, no Node) plus the hardened
  `podman run` wrapper with `--network=slirp4netns:allow_host_loopback=false`.

**Un-stub / update:**
- `tools/setup-common.sh` — replace the commented-out npm Happier stub with the `curl`
  installer, and add a Codex `curl` install alongside it:
  ```bash
  curl -fsSL https://chatgpt.com/codex/install.sh | sh
  curl -fsSL https://happier.dev/install | bash
  ```
  **Claude Code stays installed here for now** — this migration does not remove it from
  the host; it is simply not installed in the sandbox.

## Decisions locked

- **Agent:** migrate to Codex; `dan` = `codex --dangerously-bypass-approvals-and-sandbox`.
- **Installs:** Codex `curl -fsSL https://chatgpt.com/codex/install.sh | sh` and Happier
  `curl -fsSL https://happier.dev/install | bash` (curl-to-shell, not npm — both
  Node-free), in both `setup-common.sh` and the container image.
- **Relay:** Happier Cloud (hosted).
- **Linux network:** `--network=slirp4netns:allow_host_loopback=false`.
- **Claude Code:** stays on the host (`setup-common.sh`); not installed in the sandbox.

## Open items to resolve during implementation

- Re-confirm the Codex `--yolo` / `--dangerously-bypass-approvals-and-sandbox` flag and
  the install-script URL against the installed version at build time.
- Re-verify Happier's daemon subcommands (`daemon service install` / `start`) against
  live docs — it's alpha and version-volatile.
