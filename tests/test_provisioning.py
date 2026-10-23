#!/usr/bin/env python3
"""Run provisioning regressions with isolated files and fake system commands."""
# /// script
# requires-python = ">=3.11"
# ///
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

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

    host_codex = cli[cli.index('## Codex CLI'):cli.index('ACTIVE_CODEX=')]
    fake_codex = base / 'fake-codex'
    fake_codex.write_text('#!/bin/sh\n[ "$1" = update ] || exit 99\n'
                          'printf "update\\n" >> "$CALL_LOG"\n'
                          '[ "$FAIL_UPDATE" != yes ]\n')
    fake_codex.chmod(0o755)
    branch_installer = base / 'branch-installer'
    branch_installer.write_text('printf "%s\\n%s\\n" "$CODEX_INSTALL_DIR" "$CODEX_NON_INTERACTIVE" > "$RESULT"\n'
                                '/bin/mkdir -p "$CODEX_INSTALL_DIR"\n'
                                '/bin/cp "$FAKE_CODEX" "$CODEX_INSTALL_DIR/codex"\n')
    for state in ('present', 'absent', 'update-failure', 'install-failure'):
        case_dir = base / f'codex-{state}'
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
        checked = run(host_codex.replace('$HOME', '$TEST_INSTALL_ROOT'), branch_env)
        assert calls_file.read_text() == ('update\n' if state in ('present', 'update-failure') else 'install\n')
        assert ('failed' in checked.stderr) == state.endswith('failure')
        if state == 'absent':
            assert (case_dir / 'result').read_text() == f'{install_root}/.local/bin\ntrue\n'
            assert os.access(install_root / '.local/bin/codex', os.X_OK)
        else:
            assert not (install_root / '.local/bin/codex').exists()

    instructions = cli[cli.index('## Global agent instructions'):]
    instruction_home = base / 'instructions'
    instruction_home.mkdir()
    instruction_source = base / 'instructions.md'
    instruction_source.write_text('Shared rules\n<!-- ONLY:codex -->\nCodex guidance\n<!-- /ONLY:codex -->\n')
    instruction_env = dict(env, HOME=str(instruction_home), SOURCE=str(instruction_source))
    curl = 'curl() { [ "${FAIL_FETCH:-}" != yes ] || return 1; cp "$SOURCE" "$4"; }\n'
    for _ in range(2):
        run(curl + instructions, instruction_env)
        for destination in ('.claude/CLAUDE.md', '.codex/AGENTS.md'):
            assert (instruction_home / destination).read_bytes() == instruction_source.read_bytes()
    for failure in ('failed', 'empty'):
        instruction_source.write_text('' if failure == 'empty' else 'partial download')
        before = [(instruction_home / destination).read_bytes()
                  for destination in ('.claude/CLAUDE.md', '.codex/AGENTS.md')]
        run(curl + instructions, dict(instruction_env, FAIL_FETCH='yes' if failure == 'failed' else 'no'))
        assert before == [(instruction_home / destination).read_bytes()
                          for destination in ('.claude/CLAUDE.md', '.codex/AGENTS.md')]

    claude_mcp = (ROOT / 'tools/setup-claude-mcp.sh').read_text()
    # Supply the menu selection without launching authentication or requesting a PAT.
    existing_servers = run('claude() { [ "$1 $2" = "mcp get" ]; }\n' +
                           '{\n' + claude_mcp + '\n} <<< 1', env)
    assert existing_servers.stdout.count('Keeping existing ') == 3

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

print('Provisioning regressions passed (Bash startup, Git, Codex installer, shared instructions, Firefox retries).')
