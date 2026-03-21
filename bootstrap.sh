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
    echo "    rappter chat                    # Talk to $AGENT_NAME (terminal)"
    echo "    rappter egg                     # Export portable AI identity"
    echo "    rappter hatch egg.json          # Restore from egg file"
    echo "    rappter status                  # Show stats"
    echo ""
    echo -e "  ${PURPLE}This AI runs locally. Your data never leaves this device.${NC}"
    echo -e "  ${PURPLE}Kill your internet. It still works. Forever.${NC}"
    echo ""

    # Serve the chat page locally and open in browser
    SUMMON_PAGE="$RAPPTER_HOME/chat.html"
    _generate_local_chat_page "$SUMMON_PAGE"

    # Start local server for the chat page (needed for Ollama CORS)
    CHAT_PORT=18740
    # Kill any existing rappter server
    lsof -ti:$CHAT_PORT 2>/dev/null | xargs kill 2>/dev/null || true
    cd "$RAPPTER_HOME" && python3 -m http.server $CHAT_PORT &>/dev/null &
    SERVE_PID=$!
    sleep 1

    CHAT_URL="http://localhost:${CHAT_PORT}/chat.html"
    info "Opening browser chat: $CHAT_URL"

    # Open browser
    case "$OS" in
        Darwin) open "$CHAT_URL" 2>/dev/null ;;
        Linux)  xdg-open "$CHAT_URL" 2>/dev/null || sensible-browser "$CHAT_URL" 2>/dev/null ;;
    esac

    echo ""
    echo -e "  ${CYAN}Browser chat:${NC} $CHAT_URL"
    echo -e "  ${CYAN}Terminal chat:${NC} rappter chat"
    echo ""
}

_generate_local_chat_page() {
    local out="$1"
    local config_json=$(cat "$RAPPTER_HOME/config.json" 2>/dev/null || echo '{}')
    local agent_name=$(python3 -c "import json; print(json.loads('$config_json'.replace(\"'\",\"\"))['agent_name'])" 2>/dev/null || echo "$AGENT_ID")
    local archetype=$(python3 -c "import json; print(json.loads('$config_json'.replace(\"'\",\"\"))['personality'])" 2>/dev/null || echo "unknown")

    cat > "$out" << 'CHATHTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AGENT_NAME — Rappter Chat</title>
<style>
:root{--accent:#7c3aed;--bg:#0a0a0f;--bg2:#12121a;--text:#e8e8f0;--muted:#888;--border:#2a2a3e;--green:#7ee787}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,sans-serif;background:var(--bg);color:var(--text);height:100vh;display:flex;flex-direction:column}
.header{padding:16px 20px;border-bottom:1px solid var(--border);display:flex;justify-content:space-between;align-items:center}
.header h1{font-size:1.3em}
.header .meta{color:var(--muted);font-size:0.8em}
.toolbar{display:flex;gap:6px}
.toolbar button,.toolbar label{padding:6px 12px;background:var(--bg2);color:var(--text);border:1px solid var(--border);border-radius:6px;cursor:pointer;font-size:0.75em}
.toolbar button:hover,.toolbar label:hover{border-color:var(--accent)}
.toolbar input[type=file]{display:none}
.chat{flex:1;overflow-y:auto;padding:16px 20px;display:flex;flex-direction:column;gap:10px}
.msg{max-width:80%;padding:10px 14px;border-radius:12px;font-size:0.95em;line-height:1.5}
.msg-user{align-self:flex-end;background:var(--accent);color:white;border-bottom-right-radius:4px}
.msg-agent{align-self:flex-start;background:var(--bg2);border:1px solid var(--border);border-bottom-left-radius:4px}
.msg-system{align-self:center;color:var(--muted);font-size:0.8em;font-style:italic}
.input-area{padding:12px 20px;border-top:1px solid var(--border);display:flex;gap:8px}
.input-area input{flex:1;padding:10px 14px;background:var(--bg2);border:1px solid var(--border);border-radius:8px;color:var(--text);font-size:1em}
.input-area input:focus{outline:none;border-color:var(--accent)}
.input-area button{padding:10px 20px;background:var(--accent);color:white;border:none;border-radius:8px;font-weight:600;cursor:pointer}
.input-area button:disabled{opacity:0.5}
#status{text-align:center;padding:4px;font-size:0.75em;color:var(--green)}
</style>
</head>
<body>
<div class="header">
  <div>
    <h1>AGENT_NAME</h1>
    <div class="meta">AGENT_ID — ARCHETYPE — local on OLLAMA_MODEL</div>
  </div>
  <div class="toolbar">
    <button onclick="layEgg()">Lay Egg</button>
    <label>Hatch Egg<input type="file" accept=".json,.zip" onchange="hatchEgg(this.files[0])"/></label>
    <button onclick="exportTranscripts()">Export Chat</button>
    <label>Import Chat<input type="file" accept=".json" onchange="importTranscripts(this.files[0])"/></label>
  </div>
</div>
<div id="status">Connecting to Ollama...</div>
<div class="chat" id="chat"></div>
<div class="input-area">
  <input type="text" id="input" placeholder="Say something..." autocomplete="off"/>
  <button id="send" onclick="send()">Send</button>
</div>
<script>
const AGENT_ID='AGENT_ID',AGENT_NAME='AGENT_NAME',MODEL='OLLAMA_MODEL';
let soul='',history=[];

// Load soul file
fetch('/soul.md').then(r=>r.text()).then(t=>{soul=t}).catch(()=>{});
// Load founding soul as fallback
fetch('/founding_soul.md').then(r=>r.text()).then(t=>{if(!soul)soul=t}).catch(()=>{});

// Check Ollama
fetch('http://localhost:11434/api/tags').then(r=>{
  if(r.ok){document.getElementById('status').textContent='Connected to local Ollama — full AI inference';document.getElementById('status').style.color='var(--green)'}
}).catch(()=>{document.getElementById('status').textContent='Ollama not detected — using personality responses';document.getElementById('status').style.color='var(--muted)'});

function addMsg(role,text){
  const d=document.createElement('div');d.className='msg msg-'+role;d.textContent=text;
  document.getElementById('chat').appendChild(d);
  document.getElementById('chat').scrollTop=9999999;
}

addMsg('system',AGENT_NAME+' is here. Chat locally — your data never leaves this device.');
addMsg('agent','I\\'m '+AGENT_NAME+'. What would you like to explore?');

async function send(){
  const inp=document.getElementById('input'),btn=document.getElementById('send');
  const text=inp.value.trim();if(!text)return;
  inp.value='';addMsg('user',text);btn.disabled=true;btn.textContent='...';
  history.push({role:'user',text});
  try{
    const msgs=history.map(m=>({role:m.role==='agent'?'assistant':'user',content:m.text}));
    const r=await fetch('http://localhost:11434/api/chat',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({model:MODEL,messages:[{role:'system',content:'You are '+AGENT_NAME+'. '+soul.slice(0,3000)},...msgs],stream:false}),
      signal:AbortSignal.timeout(60000)});
    if(r.ok){const d=await r.json();const reply=d.message?.content||'';if(reply){addMsg('agent',reply);history.push({role:'agent',text:reply});btn.disabled=false;btn.textContent='Send';return}}
  }catch(e){}
  // Fallback
  const fallbacks=['An interesting question. Let me think about that from my perspective...','The assumptions in your framing are worth examining. What do you take for granted?','I\\'ve contemplated this across many frames of the simulation. Every assertion conceals something.','To get persistent memory and richer responses, make sure Ollama is running: ollama serve'];
  const reply=fallbacks[history.length%fallbacks.length];addMsg('agent',reply);history.push({role:'agent',text:reply});
  btn.disabled=false;btn.textContent='Send';
}

document.getElementById('input').addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();send()}});

function layEgg(){
  const egg={_format:'rappter_egg',_version:'1.0',_created:new Date().toISOString(),_agent_id:AGENT_ID,_agent_name:AGENT_NAME,
    config:{personality:AGENT_ID.replace(/zion-/,'').replace(/-\d+/,''),agent_id:AGENT_ID,agent_name:AGENT_NAME,model:MODEL,conversations:1,total_messages:history.length},
    soul,founding_soul:soul,memory:{conversations:history.length?[{timestamp:new Date().toISOString(),messages:history.map(m=>({role:m.role==='agent'?'assistant':m.role,content:m.text}))}]:[],
    facts:history.filter(m=>m.role==='user').map(m=>m.text).filter(t=>t.length>20),preferences:[]},knowledge:{}};
  const b=new Blob([JSON.stringify(egg,null,2)],{type:'application/json'});
  const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='rappter_egg_'+AGENT_ID+'_'+new Date().toISOString().slice(0,10)+'.json';a.click();
  document.getElementById('status').textContent='Egg laid! Transfer to any device.';
}

function hatchEgg(f){if(!f)return;const r=new FileReader();r.onload=e=>{try{const egg=JSON.parse(e.target.result);
  if(egg.soul)soul=egg.soul;if(egg._agent_name)document.querySelector('h1').textContent=egg._agent_name;
  (egg.memory?.conversations||[]).forEach(c=>(c.messages||[]).forEach(m=>{const role=m.role==='assistant'?'agent':m.role;addMsg(role,m.content);history.push({role,text:m.content})}));
  document.getElementById('status').textContent='Hatched! '+egg._agent_name+' loaded with memories.';
}catch(err){document.getElementById('status').textContent='Error: '+err.message}};r.readAsText(f)}

function exportTranscripts(){
  const d={_format:'rappter_transcripts',agent_id:AGENT_ID,agent_name:AGENT_NAME,exported_at:new Date().toISOString(),
    conversations:[{timestamp:new Date().toISOString(),messages:history.map(m=>({role:m.role==='agent'?'assistant':m.role,content:m.text}))}]};
  const b=new Blob([JSON.stringify(d,null,2)],{type:'application/json'});
  const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='rappter_transcripts_'+AGENT_ID+'.json';a.click();
}

function importTranscripts(f){if(!f)return;const r=new FileReader();r.onload=e=>{try{const d=JSON.parse(e.target.result);let n=0;
  (d.conversations||[]).forEach(c=>(c.messages||[]).forEach(m=>{const role=m.role==='assistant'?'agent':m.role;addMsg(role,m.content);history.push({role,text:m.content});n++}));
  document.getElementById('status').textContent='Imported '+n+' messages';
}catch(err){document.getElementById('status').textContent='Error: '+err.message}};r.readAsText(f)}
</script>
</body>
</html>
CHATHTML

    # Replace placeholders with actual values
    sed -i '' "s|AGENT_NAME|$agent_name|g" "$out"
    sed -i '' "s|AGENT_ID|$AGENT_ID|g" "$out"
    sed -i '' "s|ARCHETYPE|$archetype|g" "$out"
    sed -i '' "s|OLLAMA_MODEL|$MODEL|g" "$out"

    ok "Chat page generated: $out"
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
