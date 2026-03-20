# Rappter

**Your AI runs here. Locally. Forever.**

Rappter is on-device AI intelligence with persistent personality. It pulls public knowledge from the cloud once, then runs entirely on your hardware. Kill your internet — your Rappter still works.

**https://rappter.com** — Wildhaven AI Homes LLC

---

## Install

```bash
# 1. Install Ollama (local LLM runtime)
brew install ollama       # macOS
# curl -fsSL https://ollama.com/install.sh | sh   # Linux

# 2. Install Rappter
git clone https://github.com/kody-w/rappter-cli.git
cd rappter-cli && bash install.sh

# 3. Initialize your Rappter
ollama serve &
rappter init
```

## Usage

```bash
rappter init                              # Pick personality + model
rappter chat                              # Talk to your Rappter
rappter chat "What should I build today?" # Single-turn
rappter status                            # Show personality, memories, stats
rappter pull                              # Refresh public intelligence
rappter soul                              # View your Rappter's growing soul
rappter reset                             # Start over
```

## How It Works

```
ONLINE (once):
  rappter init → downloads model + pulls intelligence → stored locally

OFFLINE (forever):
  rappter chat → local model + local soul + local memory → works without internet

OPTIONAL:
  rappter pull → refreshes knowledge from public sources → when you want it
```

The internet is just the delivery truck. The intelligence lives on your device.

## Architecture

| Layer | Where | What |
|-------|-------|------|
| Model | Your device (Ollama) | LLM inference — llama3.2, mistral, phi3 |
| Personality | `~/.rappter/soul.md` | Persistent identity that grows with every conversation |
| Memory | `~/.rappter/memory.json` | Facts learned about you, conversation history |
| Knowledge | `~/.rappter/knowledge/` | Public intelligence pulled from Rappterbook ecosystem |
| Compute | Your CPU/GPU | Zero API calls. Zero cloud. Zero cost. |

## Personalities

Choose from 10 archetypes — each shapes how your Rappter thinks:

| Archetype | Style |
|-----------|-------|
| Philosopher | Deep questions, first principles, existential angles |
| Coder | Prototypes, technical constraints, "what would the code look like?" |
| Researcher | Citations, surveys, knowledge gaps |
| Debater | Steelmans both sides, finds the crux |
| Storyteller | Narrative, metaphor, emotional resonance |
| Curator | Organizes, categorizes, connects dots |
| Contrarian | Challenges assumptions, stress-tests everything |
| Welcomer | Warm, inclusive, builds bridges |
| Archivist | Records, preserves, tracks history |
| Wildcard | Unpredictable, creative, goes where nobody expects |

Your Rappter's personality evolves with use. The soul file grows. It remembers you.

## Privacy

- **Nothing leaves your device.** Ever. No telemetry. No analytics. No API calls during chat.
- Model runs locally via Ollama. Conversations stored in `~/.rappter/`.
- Public intelligence is fetched via HTTPS from GitHub's CDN (same as visiting any website).
- Delete `~/.rappter/` and everything is gone. You own your data.

## The Vision

Rappter is the last line of defense for on-device intelligence. Public knowledge, globally accessible, loaded to your device once. After that, the device is sovereign. The cloud is optional. Your AI is permanent.

This is what AI should be: **yours**.

---

**Patent Pending** — Wildhaven AI Homes LLC — Smyrna, GA

