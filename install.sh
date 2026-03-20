#!/bin/bash
# Install the rappter CLI
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ln -sf "$SCRIPT_DIR/rappter" /usr/local/bin/rappter 2>/dev/null || \
  ln -sf "$SCRIPT_DIR/rappter" "$HOME/.local/bin/rappter" 2>/dev/null || \
  { echo "Add $SCRIPT_DIR to your PATH"; exit 1; }
echo "rappter installed. Run: rappter init"
