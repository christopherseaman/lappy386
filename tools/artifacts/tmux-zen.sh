#!/usr/bin/env bash
# tmux-zen.sh - Center your active pane with blank spacer panes
# Usage: tmux-zen.sh [width]  (default: 100 cols, good for 1080p AR)
# Bind in tmux.conf:
#   bind-key Z run-shell "~/.local/bin/tmux-zen.sh"

set -euo pipefail

ZEN_TAG="@zen-spacer"
ZEN_CENTER="@zen-center"
ZEN_WIDTH_OPT="@zen-width"
DEFAULT_WIDTH=100
LOG_FILE="/tmp/tmux-zen.log"

# Logging is opt-in: `touch /tmp/tmux-zen.log` to enable, `rm` to disable.
log() {
  [ -e "$LOG_FILE" ] || return 0
  local ts panes
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  panes=$(tmux list-panes -F '#{pane_id}[s=#{@zen-spacer},c=#{@zen-center},a=#{?pane_active,1,0}]' 2>/dev/null | tr '\n' ' ')
  echo "[$ts] $* | $panes" >> "$LOG_FILE"
}

count_tagged() {
  tmux list-panes -F "#{$1}" 2>/dev/null | grep -c "^1$" || true
}

# Permissive: any zen tag means we have state to clean up. This lets toggle-off
# recover from partial states (orphan spacer, missing center, lost tag) instead
# of silently no-op'ing.
is_zen() {
  local spacers center
  spacers=$(count_tagged "$ZEN_TAG")
  center=$(count_tagged "$ZEN_CENTER")
  [ $((spacers + center)) -ge 1 ]
}

# Healthy zen has exactly 2 spacers + 1 center. Anything else is partial.
is_zen_healthy() {
  local spacers center
  spacers=$(count_tagged "$ZEN_TAG")
  center=$(count_tagged "$ZEN_CENTER")
  [ "$spacers" -eq 2 ] && [ "$center" -eq 1 ]
}

create_zen() {
  log "create_zen arg=${1:-}"
  if is_zen; then
    tmux display-message "Already in zen mode"
    return
  fi

  local center_width="${1:-$DEFAULT_WIDTH}"
  local current_pane window_width

  current_pane=$(tmux display-message -p '#{pane_id}')
  window_width=$(tmux display-message -p '#{window_width}')

  local pane_count
  pane_count=$(tmux display-message -p '#{window_panes}')
  if [ "$pane_count" -ne 1 ]; then
    tmux display-message "Zen mode requires a single pane"
    return
  fi

  local total_margin=$((window_width - center_width - 2))
  if [ "$total_margin" -lt 10 ]; then
    tmux display-message "Window too narrow for zen mode"
    return
  fi

  local side_width=$((total_margin / 2))

  # Create left spacer — -PF captures exact pane ID
  local left_pane
  left_pane=$(tmux split-window -hb -d -t "$current_pane" -l "$side_width" \
    -PF '#{pane_id}' "exec cat > /dev/null")
  tmux set-option -p -t "$left_pane" "$ZEN_TAG" 1

  # Create right spacer
  local right_pane
  right_pane=$(tmux split-window -h -d -t "$current_pane" -l "$side_width" \
    -PF '#{pane_id}' "exec cat > /dev/null")
  tmux set-option -p -t "$right_pane" "$ZEN_TAG" 1

  # Tag center pane and store width for rebalance
  tmux set-option -p -t "$current_pane" "$ZEN_CENTER" 1
  tmux set-option -w "$ZEN_WIDTH_OPT" "$center_width"

  # Size center pane
  tmux resize-pane -t "$current_pane" -x "$center_width"

  # Hide pane borders (window-scoped so only this window is affected)
  tmux set-option -w pane-border-style "fg=default,bg=default"
  tmux set-option -w pane-active-border-style "fg=default,bg=default"

  # Disable input and style spacers — select-pane -d/-P also selects the
  # target pane, so we re-select center as the final step
  tmux select-pane -t "$left_pane" -d -P 'fg=default,bg=default'
  tmux select-pane -t "$right_pane" -d -P 'fg=default,bg=default'
  tmux select-pane -t "$current_pane"

  # Register hooks: rebalance on resize, cleanup on pane exit
  tmux set-hook -w after-resize-window \
    "run-shell '~/.local/bin/tmux-zen.sh --rebalance'"
  tmux set-hook -w pane-exited \
    "run-shell '~/.local/bin/tmux-zen.sh --cleanup'"

  tmux display-message "Zen mode on (${center_width} cols)"
}

destroy_zen() {
  local quiet="${1:-}"
  log "destroy_zen quiet=$quiet"

  if ! is_zen; then
    [ -z "$quiet" ] && tmux display-message "Not in zen mode"
    return
  fi

  # Unset hooks FIRST — killing spacers and resizing the window would
  # otherwise fire pane-exited/after-resize-window callbacks mid-teardown.
  tmux set-hook -uw after-resize-window 2>/dev/null || true
  tmux set-hook -uw pane-exited 2>/dev/null || true

  # Focus center pane first so killing spacers doesn't shift focus
  local center
  center=$(tmux list-panes -F '#{pane_id} #{@zen-center}' | grep ' 1$' | cut -d' ' -f1 || true)
  if [ -n "$center" ]; then
    tmux select-pane -t "$center"
    tmux set-option -pu -t "$center" "$ZEN_CENTER"
  fi

  # Kill spacer panes (tolerate already-dead panes)
  for pane in $(tmux list-panes -F '#{pane_id} #{@zen-spacer}' | grep ' 1$' | cut -d' ' -f1); do
    tmux kill-pane -t "$pane" 2>/dev/null || true
  done

  # Clean up window options
  tmux set-option -wu "$ZEN_WIDTH_OPT" 2>/dev/null || true
  tmux set-option -wu pane-border-style 2>/dev/null || true
  tmux set-option -wu pane-active-border-style 2>/dev/null || true

  log "destroy_zen done"
  [ -z "$quiet" ] && tmux display-message "Zen mode off"
}

# Called by pane-exited hook — if anything zen-related is now incomplete,
# tear down whatever's left. The original version only reacted to a missing
# center, leaving orphan spacers if a spacer died first.
cleanup_zen() {
  log "cleanup_zen"
  if ! is_zen; then
    return
  fi

  if ! is_zen_healthy; then
    log "cleanup_zen partial-state -> destroy"
    destroy_zen --quiet
  fi
}

rebalance_zen() {
  log "rebalance_zen"
  if ! is_zen_healthy; then
    return
  fi

  local center_width window_width
  center_width=$(tmux display-message -p "#{$ZEN_WIDTH_OPT}")
  window_width=$(tmux display-message -p '#{window_width}')

  # Fall back to default if width option is missing
  if [ -z "$center_width" ] || [ "$center_width" = "0" ]; then
    center_width=$DEFAULT_WIDTH
  fi

  local total_margin=$((window_width - center_width - 2))
  if [ "$total_margin" -lt 10 ]; then
    destroy_zen
    return
  fi

  local side_width=$((total_margin / 2))

  # Resize each spacer pane
  for pane in $(tmux list-panes -F '#{pane_id} #{@zen-spacer}' | grep ' 1$' | cut -d' ' -f1); do
    tmux resize-pane -t "$pane" -x "$side_width"
  done
}

case "${1:-}" in
  --rebalance) rebalance_zen ;;
  --cleanup)   cleanup_zen ;;
  *)
    log "toggle arg=${1:-}"
    if is_zen; then
      destroy_zen
    else
      create_zen "${1:-}"
    fi
    ;;
esac
