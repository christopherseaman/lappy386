#!/usr/bin/env python3
"""Run provisioning regressions with isolated files and fake system commands."""
# /// script
# requires-python = ">=3.11"
# ///
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[1]


def run(script, env, check=True):
    return subprocess.run(['bash', '-euo', 'pipefail', '-c', script], env=env,
                          check=check, capture_output=True, text=True)


with tempfile.TemporaryDirectory() as tmp:
    base = Path(tmp)
    env = dict(os.environ, GIT_CONFIG_GLOBAL=str(base / 'gitconfig'))
    run('git config --global --add push.autoSetupRemote false\n'
        'git config --global --add push.autoSetupRemote true', env)
    git_line = next(line for line in (ROOT / 'tools/setup-common.sh').read_text().splitlines()
                    if 'push.autoSetupRemote' in line)
    run(git_line + '\n' + git_line, env)
    assert run('git config --global --get-all push.autoSetupRemote', env).stdout == 'true\n'

    cli = (ROOT / 'tools/setup-cli.sh').read_text()
    shell_deploy = cli[cli.index('## Shell dotfiles'):cli.index('## Starship prompt')]
    bashrc = (ROOT / 'tools/artifacts/dot-bashrc').read_text()
    bashrc_guard = bashrc[:bashrc.index("# User's private bin")]
    # Exercise the real deployment and startup guard without initializing host tools.
    for active_profile in (None, '.profile', '.bash_login', '.bash_profile'):
        for already_sources_rc in (False, True):
            shell_dir = base / f'shell-{active_profile}-{already_sources_rc}'
            (shell_dir / '.local/bin').mkdir(parents=True)
            (shell_dir / '.config').mkdir()
            profile = shell_dir / (active_profile or '.profile')
            original_profile = 'LOGIN_ENV=preserved\n'
            if already_sources_rc:
                original_profile += '. "$TEST_SHELL_DIR/.bashrc"\n'
            if active_profile:
                profile.write_text(original_profile)
            # A lower-priority profile must remain untouched and unselected.
            if active_profile in ('.bash_login', '.bash_profile'):
                (shell_dir / '.profile').write_text('LOGIN_ENV=wrong\n')
            shell_env = dict(env, TEST_SHELL_DIR=str(shell_dir), TEST_LOGIN_PROFILE=str(profile))
            deploy = shell_deploy.replace('$HOME', '$TEST_SHELL_DIR').replace('~/', shlex.quote(str(shell_dir)) + '/')
            run(f'cd {shlex.quote(str(ROOT / "tools"))}\n' + deploy, shell_env)
            deployed = profile.read_text()
            run(f'cd {shlex.quote(str(ROOT / "tools"))}\n' + deploy, shell_env)
            assert profile.read_text() == deployed
            if active_profile:
                assert deployed.startswith(original_profile)
            if active_profile in ('.bash_login', '.bash_profile'):
                assert (shell_dir / '.profile').read_text() == 'LOGIN_ENV=wrong\n'
            assert (shell_dir / '.bashrc').read_text() == bashrc
            (shell_dir / '.bashrc').write_text(bashrc_guard + 'RC_COUNT=$((${RC_COUNT:-0} + 1))\n')
            login = subprocess.run(['bash', '--noprofile', '--norc', '-lic',
                                    '. "$TEST_LOGIN_PROFILE"; printf "%s:%s\\n" "${LOGIN_ENV:-}" "${RC_COUNT:-0}"'],
                                   env=shell_env, check=True, capture_output=True, text=True)
            assert login.stdout == f'{"preserved" if active_profile else ""}:1\n'
            nonlogin = subprocess.run(['bash', '--noprofile', '--rcfile', str(shell_dir / '.bashrc'), '-ic',
                                       'printf "%s\\n" "${RC_COUNT:-0}"'],
                                      env=shell_env, check=True, capture_output=True, text=True)
            assert nonlogin.stdout == '1\n'
            assert run('. "$TEST_LOGIN_PROFILE"; printf "%s\\n" "${RC_COUNT:-0}"', shell_env).stdout == '0\n'

    pipeline = cli[cli.index('  curl -fsSL https://chatgpt.com/codex/install.sh'):cli.index('\nfi', cli.index('## Codex CLI'))]
    installer = base / 'installer'
    installer.write_text('printf "%s\\n%s\\n" "$CODEX_INSTALL_DIR" "$CODEX_NON_INTERACTIVE" > "$RESULT"\n')
    env.update(INSTALLER=str(installer), RESULT=str(base / 'result'))
    run('curl() { cat "$INSTALLER"; }\n' + pipeline, env)
    assert (base / 'result').read_text() == f"{env['HOME']}/.local/bin\ntrue\n"

    mac = (ROOT / 'tools/sandbox/setup-sandbox-mac.sh').read_text()
    mac_pipeline = next(line for line in mac.splitlines()
                        if 'curl -fsSL https://chatgpt.com/codex/install.sh' in line)
    run('curl() { cat "$INSTALLER"; }\n' + mac_pipeline, env)
    assert (base / 'result').read_text() == f"{env['HOME']}/.local/bin\ntrue\n"

    host_codex = cli[cli.index('## Codex CLI'):cli.index('ACTIVE_CODEX=')]
    guest_start = mac.index('  tart exec "$VM_NAME" /bin/sh -lc \'\n    set -e\n')
    guest_end = mac.index('\n\n  rm -f "$merged_config"', guest_start)
    guest_codex = 'VM_NAME=test-vm\ntart() { /bin/sh -c "$5"; }\n' + mac[guest_start:guest_end]
    fake_codex = base / 'fake-codex'
    fake_codex.write_text('#!/bin/sh\n[ "$1" = update ] || exit 99\n'
                          'printf "update\\n" >> "$CALL_LOG"\n'
                          '[ "$FAIL_UPDATE" != yes ]\n')
    fake_codex.chmod(0o755)
    branch_installer = base / 'branch-installer'
    branch_installer.write_text('printf "%s\\n%s\\n" "$CODEX_INSTALL_DIR" "$CODEX_NON_INTERACTIVE" > "$RESULT"\n'
                                '/bin/mkdir -p "$CODEX_INSTALL_DIR"\n'
                                '/bin/cp "$FAKE_CODEX" "$CODEX_INSTALL_DIR/codex"\n')
    for scope, script in (('host', host_codex), ('guest', guest_codex)):
        for state in ('present', 'absent', 'update-failure', 'install-failure'):
            case_dir = base / f'codex-{scope}-{state}'
            commands = case_dir / 'commands'
            commands.mkdir(parents=True)
            for shell in ('bash', 'sh'):
                (commands / shell).symlink_to(f'/bin/{shell}')
            (commands / 'curl').write_text('#!/bin/sh\nprintf "install\\n" >> "$CALL_LOG"\n'
                                           '[ "$FAIL_INSTALL" != yes ] || exit 7\n'
                                           '/bin/cat "$INSTALLER"\n')
            (commands / 'curl').chmod(0o755)
            if state in ('present', 'update-failure'):
                # An existing command outside ~/.local/bin must also be updated.
                (commands / 'codex').symlink_to(fake_codex)
            install_root = case_dir / 'user'
            calls_file = case_dir / 'calls'
            branch_env = dict(env, PATH=str(commands), TEST_INSTALL_ROOT=str(install_root),
                              CALL_LOG=str(calls_file), RESULT=str(case_dir / 'result'),
                              INSTALLER=str(branch_installer), FAKE_CODEX=str(fake_codex),
                              FAIL_UPDATE='yes' if state == 'update-failure' else 'no',
                              FAIL_INSTALL='yes' if state == 'install-failure' else 'no')
            checked = run(script.replace('$HOME', '$TEST_INSTALL_ROOT'), branch_env)
            assert calls_file.read_text() == ('update\n' if state in ('present', 'update-failure') else 'install\n')
            assert ('failed' in checked.stderr) == state.endswith('failure')
            if state == 'absent':
                assert (case_dir / 'result').read_text() == f'{install_root}/.local/bin\ntrue\n'
                assert os.access(install_root / '.local/bin/codex', os.X_OK)
            else:
                assert not (install_root / '.local/bin/codex').exists()

    recreate_default = next(line for line in mac.splitlines() if line.startswith('RECREATE_VM='))
    recreate_block = mac[mac.index('if [[ "$RECREATE_VM"'):mac.index('# Clone the prebuilt Xcode image')]
    fake_vm_commands = '''
    VM_NAME=test-vm
    LAUNCHD_DOMAIN=gui/test
    LAUNCH_LABEL=test-vm
    launchctl() { printf 'launchctl %s\\n' "$*"; }
    tart() { printf 'tart %s\\n' "$*"; }
    '''
    default_env = {key: value for key, value in env.items() if key != 'SANDBOX_RECREATE_VM'}
    reused = run(fake_vm_commands + recreate_default + '\n' + recreate_block, default_env)
    assert 'Reusing existing VM' in reused.stdout
    assert 'tart delete' not in reused.stdout and 'launchctl bootout' not in reused.stdout
    recreated = run(fake_vm_commands + recreate_default + '\n' + recreate_block,
                    dict(default_env, SANDBOX_RECREATE_VM='1'))
    assert 'tart stop test-vm' in recreated.stdout
    assert 'tart delete test-vm' in recreated.stdout

    provision_guest = mac[mac.index('provision_guest_state() {'):mac.index('configure_guest_hostname() {')]
    guest = base / 'guest.toml'
    host = base / 'host.toml'
    host.write_text('model = "host-choice"\n[projects.host]\ntrust_level = "trusted"\n')
    env.update(GUEST_CONFIG=str(guest), HOST_CONFIG=str(host), PYTHON_BIN=sys.executable,
               MERGER=str(ROOT / 'tools/merge-codex-config.py'), SCRIPT_DIR=str(ROOT / 'tools/sandbox'))
    guest_commands = '''
    VM_NAME=test-vm
    wait_for_tart_exec() { return 0; }
    cp() { command cp "$HOST_CONFIG" "$2"; }
    uv() {
      [ "${FAIL_MERGE:-}" != yes ] || return 1
      "$PYTHON_BIN" "$MERGER" sandbox "${@: -1}"
    }
    tart() {
      if [ "$2" = -i ]; then
        cat > "$GUEST_CONFIG"
      elif [[ "$*" == *'cat "$HOME/.codex/config.toml"'* ]]; then
        [ "${FAIL_READ:-}" != yes ] || return 1
        [ -e "$GUEST_CONFIG" ] || return 3
        cat "$GUEST_CONFIG"
      fi
    }
    '''
    guest.write_text('model = "guest-choice"\n[projects.guest]\ntrust_level = "trusted"\n')
    run(guest_commands + provision_guest + '\nprovision_guest_state', env)
    merged = tomllib.loads(guest.read_text())
    assert merged['projects'] == {'guest': {'trust_level': 'trusted'}}
    assert merged['approval_policy'] == 'never' and merged['sandbox_mode'] == 'danger-full-access'
    original = guest.read_bytes()
    for failure in ('FAIL_READ', 'FAIL_MERGE'):
        run(guest_commands + provision_guest + '\nprovision_guest_state', dict(env, **{failure: 'yes'}))
        assert guest.read_bytes() == original
    guest.unlink()
    run(guest_commands + provision_guest + '\nprovision_guest_state', env)
    assert tomllib.loads(guest.read_text())['projects'] == {'host': {'trust_level': 'trusted'}}

    apt = base / 'apt'
    for directory in ('sources.list.d', 'preferences.d', 'keyrings'):
        (apt / directory).mkdir(parents=True)
    firefox = (ROOT / 'tools/setup-firefox.sh').read_text().replace('/etc/apt', str(apt))
    env.update(LOG=str(base / 'log'), PREF=str(apt / 'preferences.d/mozilla'))
    # Fail after the source is written, then rerun the real helper against temp files.
    fake_commands = '''
    sudo() {
      printf '%s\\n' "$*" >> "$LOG"
      case "$1" in
        tee)
          if [ "$2" = "$PREF" ] && [ "${FAIL_PREF:-}" = yes ]; then return 1; fi
          command tee "$2" ;;
        install) command install "${@:2}" ;;
        apt) [ "$2" != purge ] || { echo 'unexpected purge' >&2; return 99; } ;;
        *) return 99 ;;
      esac
    }
    snap() { return 1; }
    dpkg() { return 1; }
    wget() { printf 'test signing key\\n'; }
    '''
    failed = run(fake_commands + firefox, dict(env, FAIL_PREF='yes'), check=False)
    assert failed.returncode != 0
    assert (apt / 'sources.list.d/mozilla.sources').is_file()
    assert not (apt / 'preferences.d/mozilla').exists()
    # Pretend Firefox is already installed on retries: the migration must stay skipped.
    retry = fake_commands + '\ndpkg() { echo "ii firefox installed"; }\n' + firefox
    run(retry, env)
    run(retry, env)
    assert 'Pin-Priority: 1000' in (apt / 'preferences.d/mozilla').read_text()
    calls = (base / 'log').read_text()
    assert calls.count('apt install --quiet -qq -y firefox\n') == 2
    assert calls.count('apt update --quiet -qq\n') == 2
    assert 'purge' not in calls
    assert calls.count('install -d -m 0755') == 1

    debian = (ROOT / 'tools/setup-debian.sh').read_text()
    firefox_block = debian[debian.index('## Firefox from Mozilla'):debian.index('# Install or update Neovim')]
    assert 'mozilla.sources' not in firefox_block
    assert '"$SCRIPT_DIR/setup-firefox.sh"' in firefox_block

print('Provisioning regressions passed (Bash startup, Git, Codex installers, VM opt-in/state, Firefox retries).')
