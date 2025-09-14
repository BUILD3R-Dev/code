#!/usr/bin/env bash
# Install or update the Just Every Code TUI with custom prompts + args injection
# and expose it under a convenient command name (default: codex+).
#
# Usage:
#   scripts/install-codex-plus.sh --repo https://github.com/<you>/code --rev <commit_sha> [--link-name codex+]
#
# Notes:
# - Requires a Git repo you control that contains your patched code.
# - The script installs the crate via `cargo install --git ... --rev ...` for reproducibility,
#   then creates a symlink in ~/.local/bin so you can run it from any project.

set -euo pipefail

REPO_URL=""
REV=""
LINK_NAME="codex+"
CRATE_NAME="codex-tui"
BIN_NAME="code-tui"

usage() {
  cat <<USAGE
Install Codex+ (custom prompts + args injection) from a Git commit.

Required flags:
  --repo <url>         Git URL of your fork (e.g., https://github.com/yourname/code)
  --rev <commit>       Commit SHA to install (pin exact version)

Optional flags:
  --link-name <name>   Command name to create (default: codex+)

Examples:
  scripts/install-codex-plus.sh \
    --repo https://github.com/yourname/code \
    --rev  abcdef1234567890 \
    --link-name codex+
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_URL=${2:-}; shift 2 ;;
    --rev)
      REV=${2:-}; shift 2 ;;
    --link-name)
      LINK_NAME=${2:-}; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage; exit 2 ;;
  esac
done

if [[ -z "$REPO_URL" || -z "$REV" ]]; then
  echo "error: --repo and --rev are required" >&2
  usage
  exit 2
fi

echo "==> Installing prerequisites (Rust toolchain)"

# Prefer rustup-init via Homebrew on macOS if available; otherwise use curl.
if ! command -v cargo >/dev/null 2>&1; then
  if [[ "$(uname -s)" == "Darwin" ]] && command \
      -v brew >/dev/null 2>&1 && ! command -v rustup-init >/dev/null 2>&1; then
    # If Homebrew cellar perms block install, the command will guide the user.
    brew install rustup-init || true
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    yes | rustup-init -y --no-modify-path || true
  fi
fi

# Source cargo env for current shell (zsh/bash)
if [[ -f "$HOME/.cargo/env" ]]; then
  # shellcheck disable=SC1090
  . "$HOME/.cargo/env"
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "error: cargo is still not available on PATH" >&2
  echo "hint: ensure \"source \$HOME/.cargo/env\" is loaded in your shell (e.g., ~/.zshrc)" >&2
  exit 1
fi

echo "==> Installing from git: $REPO_URL @ $REV"
cargo install \
  --git "$REPO_URL" \
  --rev "$REV" \
  "$CRATE_NAME" \
  --bin "$BIN_NAME" \
  --force

INSTALL_BIN="$HOME/.cargo/bin/$BIN_NAME"
if [[ ! -x "$INSTALL_BIN" ]]; then
  echo "error: expected installed binary not found: $INSTALL_BIN" >&2
  exit 1
fi

DEST_DIR="$HOME/.local/bin"
mkdir -p "$DEST_DIR"
ln -sf "$INSTALL_BIN" "$DEST_DIR/$LINK_NAME"

# Ensure ~/.local/bin is on PATH for future shells
if [[ -n "${SHELL:-}" && "$SHELL" == */zsh ]]; then
  ZRC="$HOME/.zshrc"
  if ! grep -q 'export PATH="\$HOME/.local/bin:\$PATH"' "$ZRC" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZRC"
    echo "Appended ~/.local/bin to PATH in $ZRC"
  fi
fi

echo "\n==> Installed: $DEST_DIR/$LINK_NAME -> $INSTALL_BIN"
echo "Run: $LINK_NAME"
echo "Prompts path: \${CODEX_HOME:-$HOME/.codex}/prompts (supports {{args}})"

