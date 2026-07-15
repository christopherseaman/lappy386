# TODO

## Zellij (evaluating vs tmux)

- [ ] Decide: adopt zellij or stay on tmux
  - Currently "kicking the tires"; tmux stays fully intact during evaluation.
  - Already in place: `zellij` + `zoxide` in `brew.lst` and `setup-debian.sh`; `bye`/`yank` are multiplexer-aware; `tools/artifacts/zellij-config.kdl` (compact layout) propagated via `setup-common.sh`.
  - [ ] If adopting: finish the SSH auto-attach + zen items below and update CLAUDE.md's tmux notes
  - [ ] If not: remove zellij from `brew.lst` / `setup-debian.sh`, drop the `config.kdl` propagation, and delete `zellij-config.kdl`

- [ ] Make SSH auto-attach multiplexer-aware
  - `dot-bashrc` and `dot-zshrc` both auto-attach tmux on SSH login, guarded only by `[[ -z "$TMUX" ]]`.
  - Inside a zellij session that guard is false-negative, so it would still launch tmux nested inside zellij.
  - [ ] Broaden the guard to `[[ -z "$TMUX$ZELLIJ" ]]` in both rc files so neither multiplexer nests
    - `$ZELLIJ` is set to "0" inside a session; `$ZELLIJ_SESSION_NAME` holds the name.
  - [ ] Decide which multiplexer SSH auto-launches while evaluating (keep tmux default, or gate on a host/env var)

- [ ] Zen / centered max-width layout equivalent
  - `tmux-zen.sh` centers a fixed-width pane using disabled spacer panes plus an `after-resize-window` rebalance hook.
  - Zellij has no runtime scripting hook for this; the model is declarative layouts + floating panes (toggle with `Ctrl+p w`, default opens centered).
  - Fixed max-width is the one case with no out-of-box parity: percentage widths auto-reflow/recenter on resize, but a fixed-column floating pane keeps its size and does NOT auto-recenter.
  - [ ] Prototype a `swap_floating_layout` for a ~100-col centered pane, shipped commented-out (opt-in, stays out-of-box)
    - Zellij is installed locally now, so this can be tried interactively.
  - [ ] Compare percentage-width (auto-reflow) vs fixed max-width (no recenter) and pick the acceptable tradeoff
  - [ ] Decide whether fixed-width-that-recenters is worth a WASM plugin (likely not)

- [ ] Confirm the double-status-bar fix holds in practice
  - Compact layout (already deployed) drops zellij's verbose bottom status bar, leaving a thin tab bar.
  - `showtabline=0` was rejected: it hides nvim's buffer list (useful nav info) and targets the wrong bar.
  - [ ] Use zellij + nvim day-to-day and check the thin tab bar doesn't stack awkwardly under nvim's lualine
  - [ ] If still cluttered: evaluate a custom no-tab-bar layout or `zjstatus`
    - `zjstatus`: https://github.com/dj95/zjstatus
  - [ ] Verify the compact bar's powerline arrow separators render (Nerd/powerline font); fallback is `zellij options --simplified-ui true`

- [ ] Optional: zellij session aliases
  - Low value since starting a session is infrequent.
  - [ ] Add `zj`/`zja` (attach-or-create)/`zjl` (list) if they earn their keep
