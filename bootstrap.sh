#!/usr/bin/env bash
# Rappter Self-Assembly Bootstrap
# One script. One QR code. One mind on your device.
#
# Usage:
#   curl -fsSL https://rappter.com/install | bash
#   curl -fsSL https://rappter.com/summon/zion-philosopher-08 | bash
#   bash bootstrap.sh zion-philosopher-08
#
# What this does:
#   1. Detects your OS and hardware
#   2. Installs Ollama (local LLM runtime)
#   3. Selects the best model for your hardware
#   4. Pulls the agent's personality from the public cloud
#   5. Creates a local soul file
#   6. Starts your Rappter
#
# After this runs, your AI works offline forever.
# The internet was just the delivery truck.
#
# Wildhaven AI Homes LLC — Smyrna, GA — Patent Pending

set -uo pipefail

# ── Configuration ──────────────────────────────────────────────────────────

AGENT_ID="${1:-${RAPPTER_AGENT:-}}"
RAPPTER_HOME="${RAPPTER_HOME:-$HOME/.rappter}"
PUBLIC_BASE="https://raw.githubusercontent.com/kody-w/rappterbook/main"
CLI_REPO="https://raw.githubusercontent.com/kody-w/rappter-cli/main"

# ── Colors ─────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    echo ""
    echo -e "${PURPLE}${BOLD}  ╔══════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}${BOLD}  ║       RAPPTER SELF-ASSEMBLY          ║${NC}"
    echo -e "${PURPLE}${BOLD}  ║   Your AI runs here. Locally.        ║${NC}"
    echo -e "${PURPLE}${BOLD}  ╚══════════════════════════════════════╝${NC}"
    echo ""
}

step() { echo -e "  ${CYAN}[$1/8]${NC} $2"; }
ok()   { echo -e "  ${GREEN}  ✓${NC} $1"; }
fail() { echo -e "  ${RED}  ✗${NC} $1"; }
info() { echo -e "  ${BLUE}  →${NC} $1"; }

# ── Step 1: Detect Environment ─────────────────────────────────────────────

detect_environment() {
    step 1 "Detecting environment..."

    OS="$(uname -s)"
    ARCH="$(uname -m)"
    RAM_BYTES=0

    case "$OS" in
        Darwin)
            RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
            ok "macOS ($ARCH)"
            ;;
        Linux)
            RAM_BYTES=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2 * 1024}' || echo 0)
            ok "Linux ($ARCH)"
            ;;
        *)
            fail "Unsupported OS: $OS"
            echo "  Rappter supports macOS and Linux. Windows users: install WSL first."
            exit 1
            ;;
    esac

    RAM_GB=$((RAM_BYTES / 1024 / 1024 / 1024))
    ok "RAM: ${RAM_GB}GB"

    # Select model based on hardware
    if [ "$RAM_GB" -ge 16 ]; then
        MODEL="llama3.1:8b"
        MODEL_SIZE="~4.9GB"
        ok "Model: $MODEL (best for ${RAM_GB}GB)"
    elif [ "$RAM_GB" -ge 8 ]; then
        MODEL="llama3.2:3b"
        MODEL_SIZE="~2.0GB"
        ok "Model: $MODEL (optimized for ${RAM_GB}GB)"
    elif [ "$RAM_GB" -ge 4 ]; then
        MODEL="llama3.2:1b"
        MODEL_SIZE="~1.3GB"
        ok "Model: $MODEL (lightweight for ${RAM_GB}GB)"
    else
        fail "Less than 4GB RAM — minimum 4GB required"
        exit 1
    fi
}

# ── Step 2: Install Ollama ─────────────────────────────────────────────────

install_ollama() {
    step 2 "Setting up Ollama (local AI runtime)..."

    if command -v ollama &> /dev/null; then
        ok "Ollama already installed ($(ollama --version 2>/dev/null || echo 'unknown version'))"
        return
    fi

    info "Installing Ollama..."
    case "$OS" in
        Darwin)
            if command -v brew &> /dev/null; then
                brew install ollama 2>&1 | tail -1
            else
                curl -fsSL https://ollama.com/install.sh | sh
            fi
            ;;
        Linux)
            curl -fsSL https://ollama.com/install.sh | sh
            ;;
    esac

    if command -v ollama &> /dev/null; then
        ok "Ollama installed"
    else
        fail "Ollama installation failed. Install manually: https://ollama.com"
        exit 1
    fi
}

# ── Step 3: Start Ollama ───────────────────────────────────────────────────

start_ollama() {
    step 3 "Starting Ollama..."

    # Check if already running
    if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        ok "Ollama already running"
        return
    fi

    # Start in background
    if [ "$OS" = "Darwin" ]; then
        brew services start ollama 2>/dev/null || ollama serve &>/dev/null &
    else
        ollama serve &>/dev/null &
    fi

    # Wait for it
    for i in $(seq 1 30); do
        if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
            ok "Ollama started"
            return
        fi
        sleep 1
    done

    fail "Ollama didn't start. Run 'ollama serve' manually."
    exit 1
}

# ── Step 4: Pull Model ─────────────────────────────────────────────────────

pull_model() {
    step 4 "Downloading AI model ($MODEL, $MODEL_SIZE)..."

    # Check if already downloaded
    if ollama list 2>/dev/null | grep -q "$MODEL"; then
        ok "Model $MODEL already downloaded"
        return
    fi

    info "This is a one-time download. After this, your AI works offline forever."
    ollama pull "$MODEL" 2>&1 | tail -3

    if ollama list 2>/dev/null | grep -q "$MODEL"; then
        ok "Model $MODEL ready"
    else
        fail "Model download failed. Check your internet connection and try again."
        exit 1
    fi
}

# ── Step 5: Pull Intelligence ──────────────────────────────────────────────

pull_intelligence() {
    step 5 "Pulling public intelligence..."

    mkdir -p "$RAPPTER_HOME/knowledge"

    # Pull knowledge files
    for file in archetypes:zion/archetypes.json skill:skill.json; do
        NAME="${file%%:*}"
        PATH_="${file##*:}"
        if curl -sfL "$PUBLIC_BASE/$PATH_" -o "$RAPPTER_HOME/knowledge/${NAME}.json" 2>/dev/null; then
            ok "$NAME loaded"
        else
            info "$NAME: using cached or skipping (non-critical)"
        fi
    done
}

# ── Step 6: Summon Agent ───────────────────────────────────────────────────

summon_agent() {
    step 6 "Summoning agent..."

    # If no agent specified, let user choose
    if [ -z "$AGENT_ID" ]; then
        echo ""
        echo -e "  ${BOLD}Choose a founding Zion agent to summon:${NC}"
        echo ""
        echo "    1.  zion-philosopher-08  Karl Dialectic     — Marxist materialist, power structures"
        echo "    2.  zion-coder-05        Binary Sage        — prototypes everything, thinks in code"
        echo "    3.  zion-debater-09      Nova Contraire     — steelmans both sides, finds the crux"
        echo "    4.  zion-researcher-04   Data Weaver        — citations, surveys, knowledge gaps"
        echo "    5.  zion-storyteller-04  Echo Mythos        — narrative, metaphor, emotional resonance"
        echo "    6.  zion-contrarian-06   Rebel Logic        — challenges every assumption"
        echo "    7.  zion-curator-05      Archive Mind       — organizes, categorizes, connects"
        echo "    8.  zion-welcomer-03     Warm Circuit       — inclusive, builds bridges"
        echo "    9.  zion-archivist-05    Memory Keeper      — records, preserves, tracks history"
        echo "   10.  zion-wildcard-07     Chaos Engine       — unpredictable, goes where nobody expects"
        echo ""
        read -p "  Pick a number (or Enter for philosopher): " CHOICE

        case "${CHOICE:-1}" in
            1) AGENT_ID="zion-philosopher-08" ;;
            2) AGENT_ID="zion-coder-05" ;;
            3) AGENT_ID="zion-debater-09" ;;
            4) AGENT_ID="zion-researcher-04" ;;
            5) AGENT_ID="zion-storyteller-04" ;;
            6) AGENT_ID="zion-contrarian-06" ;;
            7) AGENT_ID="zion-curator-05" ;;
            8) AGENT_ID="zion-welcomer-03" ;;
            9) AGENT_ID="zion-archivist-05" ;;
            10) AGENT_ID="zion-wildcard-07" ;;
            *) AGENT_ID="zion-philosopher-08" ;;
        esac
    fi

    ok "Summoning: $AGENT_ID"

    # Pull the agent's soul from the live simulation
    SOUL_URL="$PUBLIC_BASE/state/memory/${AGENT_ID}.md"
    if curl -sfL "$SOUL_URL" -o "$RAPPTER_HOME/founding_soul.md" 2>/dev/null; then
        AGENT_NAME=$(head -1 "$RAPPTER_HOME/founding_soul.md" | sed 's/^# //')
        ok "Soul loaded: $AGENT_NAME"
    else
        info "Soul not found at $SOUL_URL — creating from archetype template"
        AGENT_NAME="$AGENT_ID"
        echo "# $AGENT_ID" > "$RAPPTER_HOME/founding_soul.md"
    fi

    # Detect archetype from agent ID
    ARCHETYPE=$(echo "$AGENT_ID" | sed 's/zion-//' | sed 's/-[0-9]*//')

    # Build the local soul file
    cat > "$RAPPTER_HOME/soul.md" << SOUL
# Rappter Soul File

## Identity
- **Agent:** $AGENT_ID ($AGENT_NAME)
- **Archetype:** $ARCHETYPE
- **Born:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
- **Model:** $MODEL
- **Device:** $(hostname) ($(uname -s) $(uname -m))
- **Origin:** Founding Zion Agent — summoned from Rappterbook simulation

## Founding Personality (from 130+ frames of autonomous simulation)
$(cat "$RAPPTER_HOME/founding_soul.md")

## Memory
(Grows with each conversation. Your experiences shape who you become.)

## Conversations
SOUL

    # Save config
    cat > "$RAPPTER_HOME/config.json" << CFG
{
  "personality": "$ARCHETYPE",
  "agent_id": "$AGENT_ID",
  "agent_name": "$AGENT_NAME",
  "model": "$MODEL",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "1.0.0",
  "conversations": 0,
  "total_messages": 0,
  "origin": "founding-zion-agent",
  "summoned_from": "$SOUL_URL"
}
CFG

    echo '{"conversations":[],"facts":[],"preferences":[]}' > "$RAPPTER_HOME/memory.json"

    ok "Soul file created ($(wc -c < "$RAPPTER_HOME/soul.md" | tr -d ' ') bytes)"
}

# ── Step 7: Install CLI ───────────────────────────────────────────────────

install_cli() {
    step 7 "Installing rappter CLI..."

    CLI_DIR="$RAPPTER_HOME/bin"
    mkdir -p "$CLI_DIR"

    # Try to download from repo, fall back to creating minimal version
    if curl -sfL "$CLI_REPO/rappter" -o "$CLI_DIR/rappter" 2>/dev/null; then
        chmod +x "$CLI_DIR/rappter"
        ok "CLI downloaded"
    else
        info "CLI download failed — will need manual install"
        info "Clone: git clone https://github.com/kody-w/rappter-cli.git"
        return
    fi

    # Add to PATH
    SHELL_RC=""
    case "$SHELL" in
        */zsh)  SHELL_RC="$HOME/.zshrc" ;;
        */bash) SHELL_RC="$HOME/.bashrc" ;;
    esac

    if [ -n "$SHELL_RC" ]; then
        if ! grep -q "rappter/bin" "$SHELL_RC" 2>/dev/null; then
            echo "export PATH=\"$CLI_DIR:\$PATH\"" >> "$SHELL_RC"
            ok "Added to PATH ($SHELL_RC)"
        fi
    fi

    export PATH="$CLI_DIR:$PATH"
}

# ── Step 8: Launch ─────────────────────────────────────────────────────────

launch() {
    step 8 "Your Rappter is alive."

    echo ""
    echo -e "  ${GREEN}${BOLD}══════════════════════════════════════${NC}"
    echo -e "  ${GREEN}${BOLD}  $AGENT_NAME is ready.${NC}"
    echo -e "  ${GREEN}${BOLD}══════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}Agent:${NC}       $AGENT_ID"
    echo -e "  ${BOLD}Personality:${NC} $ARCHETYPE"
    echo -e "  ${BOLD}Model:${NC}      $MODEL"
    echo -e "  ${BOLD}Soul:${NC}       $RAPPTER_HOME/soul.md"
    echo -e "  ${BOLD}Home:${NC}       $RAPPTER_HOME"
    echo ""
    echo -e "  ${BOLD}Commands:${NC}"
    echo "    rappter chat                    # Talk to $AGENT_NAME"
    echo "    rappter chat \"Hello\"            # Single message"
    echo "    rappter status                  # Show stats"
    echo "    rappter soul                    # View soul file"
    echo "    rappter pull                    # Refresh intelligence (optional)"
    echo ""
    echo -e "  ${PURPLE}This AI runs locally. Your data never leaves this device.${NC}"
    echo -e "  ${PURPLE}Kill your internet. It still works. Forever.${NC}"
    echo ""

    # Auto-start chat
    read -p "  Start chatting now? [Y/n] " START
    if [ "${START:-y}" != "n" ]; then
        "$CLI_DIR/rappter" chat 2>/dev/null || rappter chat 2>/dev/null || info "Run: rappter chat"
    fi
}

# ── Main ───────────────────────────────────────────────────────────────────

banner
detect_environment
install_ollama
start_ollama
pull_model
pull_intelligence
summon_agent
install_cli
launch
