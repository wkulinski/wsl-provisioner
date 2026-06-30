# --- bashrc.d loader ---------------------------------------------------------
# Script loads sh scripts into your shell
# Paste this script on the end of your .bashrc to make it work
# Usage:
#   put scripts into ~/.bashrc.d/ (or symlink them there)
#   optionally enable debug: BASHRC_D_DEBUG=1
#   force loading order by prefixing scripts with 00-, 10-, 20-, etc

__bashrc_d_log() {
  # log only when debug enabled
  [ -n "${BASHRC_D_DEBUG:-}" ] || return 0
  printf '[bashrc.d] %s\n' "$*" >&2
}

__bashrc_d_source_safe() {
  # Source a file, but don't let it permanently change:
  # - errexit (-e), nounset (-u), pipefail, xtrace, etc. during the *loading* phase.
  # Any changes the file makes to aliases/functions/vars still persist (as desired),
  # but shell option flags are restored after sourcing.
  #
  # Note: If a module sets options intentionally for the user's shell,
  # you can opt-out by not using this wrapper for that specific file.

  local f="$1"
  # save options
  local __old_opts
  __old_opts="$(set +o)"   # produces commands to restore current option state

  # Be conservative during init: avoid 'set -e/-u' surprises from modules.
  set +e +u
  set +o pipefail 2>/dev/null || true
  set +o xtrace   2>/dev/null || true

  # shellcheck source=/dev/null
  . "$f"
  local rc=$?

  # restore options
  eval "$__old_opts"
  return $rc
}

__bashrc_d_load_dir() {
  local dir="$1"
  [ -d "$dir" ] || return 0

  # Collect readable, regular files (not dirs). Support *.sh and files without ext.
  # Sort with stable byte-order (LC_ALL=C) to make 00-,10-,20- ordering predictable.
  local -a files=()
  local f

  # Globs that might be empty shouldn't expand to themselves
  shopt -s nullglob

  for f in "$dir"/* "$dir"/*.sh; do
    [ -f "$f" ] && [ -r "$f" ] && files+=("$f")
  done

  shopt -u nullglob

  # Sort
  if [ "${#files[@]}" -gt 0 ]; then
    # printf + sort to be portable
    IFS=$'\n' files=($(LC_ALL=C printf '%s\n' "${files[@]}" | sort -u))
    unset IFS
  fi

  for f in "${files[@]}"; do
    __bashrc_d_log "loading: $f"
    if ! __bashrc_d_source_safe "$f"; then
      __bashrc_d_log "ERROR($?): $f"
      # If you want hard-fail, replace 'continue' with 'return 1'
      continue
    fi
  done
}

__bashrc_d_load_dir "$HOME/.bashrc.d"
# --- end bashrc.d loader -----------------------------------------------------
