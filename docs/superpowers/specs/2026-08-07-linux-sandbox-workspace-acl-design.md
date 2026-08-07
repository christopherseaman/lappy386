# Linux Sandbox Workspace ACL Design

## Goal

Configure the Linux sandbox workspace root so the invoking user and a selected
workspace group can collaborate through the Podman bind mount. New entries must
inherit the workspace group and group read/write access.

## Scope

The change applies only to `tools/sandbox/setup-sandbox-linux.sh` and only to the
workspace root selected by `SANDBOX_WORKSPACE` (default: `$HOME/projects`). The
macOS Tart workflow and existing workspace descendants are unchanged.

## Behavior

After creating the workspace and state directories, the script will:

1. Resolve the workspace group from `SANDBOX_WORKSPACE_GROUP`, defaulting to the
   invoking user's primary group from `id -gn`.
2. Fail with a clear error if `setfacl` is unavailable. The script will not
   install the ACL package automatically.
3. Change the workspace root's group to the selected group.
4. Remove existing access and default ACLs from the workspace root.
5. Set mode `2770`, preserving the setgid bit so new descendants inherit the
   workspace group.
6. Apply exact access and default ACLs granting `rwx` to the owner and group and
   no access to others, with an `rwx` ACL mask.

All operations run before the image build and before removal of an existing
container. Under `set -euo pipefail`, an invalid group, unsupported filesystem,
or failed ACL operation aborts setup without replacing the running sandbox.

## Safety Boundaries

ACL removal and mode changes are intentionally limited to the workspace root.
The script will not recursively change ownership, modes, or ACLs. Existing files
and directories beneath the workspace keep their current metadata.

## Verification

Add a focused shell regression test that executes the setup script with command
stubs and verifies ordering and arguments without building an image or replacing
a container. The test will cover the missing-`setfacl` failure and the expected
group/mode/ACL commands before Podman operations. Also run `bash -n` on the
production script and test script. Where a Linux ACL-capable environment is
available, verify the resulting root mode and ACLs with `stat` and `getfacl`.
