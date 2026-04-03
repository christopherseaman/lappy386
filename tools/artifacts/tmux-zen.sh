#!/usr/bin/env bash
# tmux-zen.sh - Center your active pane with blank spacer panes
# Usage: tmux-zen.sh [width]  (default: 100 cols, good for 1080p AR)
# Bind in tmux.conf:
#   bind-key Z run-shell "~/.local/bin/tmux-zen.sh"

set -euo pipefail

CENTER_WIDTH="${1:-100}"
ZEN_TAG="@zen-spacer"

CURRENT_PANE=$(tmux display-message -p '#{pane_id}')
WINDOW_WIDTH=$(tmux display-message -p '#{window_width}')

is_zen() {
  local count
  count=$(tmux list-panes -F "#{@zen-spacer}" | grep -c "^1$" || true)
  [ "$count" -ge 2 ]
}

create_zen() {
  if is_zen; then
    tmux display-message "Already in zen mode"
    return
  fi

  local pane_count
  pane_count=$(tmux display-message -p '#{window_panes}')
  if [ "$pane_count" -ne 1 ]; then
    tmux display-message "Zen mode requires a single pane"
    return
  fi

  local total_margin=$((WINDOW_WIDTH - CENTER_WIDTH - 2))
  if [ "$total_margin" -lt 10 ]; then
    tmux display-message "Window too narrow for zen mode"
    return
  fi

  local side_width=$((total_margin / 2))

  # Create left spacer (before current pane, don't focus it)
  tmux split-window -hb -d -t "$CURRENT_PANE" -l "$side_width" "sleep infinity"
  local left_pane
  left_pane=$(tmux list-panes -F '#{pane_id}' | head -1)
  tmux set-option -p -t "$left_pane" "$ZEN_TAG" 1

  # Create right spacer (after current pane, don't focus it)
  tmux split-window -h -d -t "$CURRENT_PANE" -l "$side_width" "sleep infinity"
  local right_pane
  right_pane=$(tmux list-panes -F '#{pane_id}' | tail -1)
  tmux set-option -p -t "$right_pane" "$ZEN_TAG" 1

  # Ensure center pane is focused and sized correctly
  tmux select-pane -t "$CURRENT_PANE"
  tmux resize-pane -t "$CURRENT_PANE" -x "$CENTER_WIDTH"

  # Hide borders on spacer panes (tmux 3.2+)
  for pane in "$left_pane" "$right_pane"; do
    tmux select-pane -t "$pane" -P 'bg=default'
  done

  tmux display-message "Zen mode on (${CENTER_WIDTH} cols)"
}

destroy_zen() {
  if ! is_zen; then
    tmux display-message "Not in zen mode"
    return
  fi

  for pane in $(tmux list-panes -F '#{pane_id} #{@zen-spacer}' | grep ' 1$' | cut -d' ' -f1); do
    tmux kill-pane -t "$pane"
  done

  tmux display-message "Zen mode off"
}

if is_zen; then
  destroy_zen
else
  create_zen
fi
