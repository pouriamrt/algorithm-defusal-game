# Bomb Defusal: Algorithm Mode

A **serious game** for Affective Computing research where players defuse algorithm-locked bombs across 10 global cities under time pressure. Built in **Godot 4** with an optional **FastAPI + LLM** backend for dynamic AI commentary.

> **Research context**: Developed as part of a PhD project in Affective Computing at the University of Ottawa. The game serves as an experimental stimulus for studying player affect, engagement, and learning outcomes in educational gaming contexts.

---

## Table of Contents

- [Game Overview](#game-overview)
- [Architecture](#architecture)
- [Puzzle Modules](#puzzle-modules)
- [Campaign Structure](#campaign-structure)
- [Adaptive Difficulty](#adaptive-difficulty)
- [Module Variants](#module-variants)
- [AI Commentary System](#ai-commentary-system)
- [Visual Systems](#visual-systems)
- [Getting Started](#getting-started)
- [Deployment](#deployment)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)

---

## Game Overview

```
START MISSION -> Opening Briefing -> World Map -> Bomb Game -> Result Screen
                                        ^            |              |
                                        |      [3 modules at once]  |
                                        |            |              |
                                        +--- next wave (if defused) +
                                                     |
                                              [fail -> replay]
```

**Core loop**: Each wave presents 3 puzzle modules simultaneously. The player must solve all 3 before the timer expires or stability reaches zero. Solving a module teaches a computer science algorithm concept; failing it costs stability. 10 waves across 10 real-world cities form a complete campaign.

**Game mechanics**:
- **Timer**: Starts at 150s (wave 1), decreases by 10s per wave (minimum 60s)
- **Stability**: Starts at 100, loses points per wrong action. Reaches 0 = explosion
- **Modules**: 3 per wave, drawn from a pool of 10 types. Each teaches a different algorithm
- **Win condition**: Solve all 3 modules before timer or stability hits zero

---

## Architecture

```
+------------------+     +-------------------+     +------------------+
|   Main Menu      | --> | Opening Briefing  | --> |   World Map      |
+------------------+     +-------------------+     +------------------+
                                                          |
                                                          v
+------------------+     +-------------------+     +------------------+
|  Result Screen   | <-- |    Bomb Game      | <-- | Module Instances |
|  (victory/fail)  |     | (timer, stability,|     | (3 per wave)     |
+------------------+     |  commentary, bomb)|     +------------------+
                          +-------------------+

Autoload Singletons:
+-------------+  +------------------+  +-----------+  +------------+
| GameState   |  | DifficultyManager|  | WaveData  |  | LLMService |
| (runtime)   |  | (adaptive curve) |  | (static)  |  | (AI text)  |
+-------------+  +------------------+  +-----------+  +------------+
```

**Signal-driven design**: Modules emit `module_solved` and `wrong_action` signals. `GameState` emits `stability_changed`, `timer_updated`, and `game_over`. The bomb game scene orchestrates all responses.

---

## Puzzle Modules

| # | Module | Algorithm | Player Task | Variant Mode |
|---|--------|-----------|-------------|--------------|
| 1 | **Frequency Lock** | Binary Search | Guess a hidden number with high/low feedback | Hot/Cold (distance only, no direction) |
| 2 | **Signal Sorting** | Sorting / Inversions | Swap elements to sort; bad swaps penalized | Descending sort (30%) |
| 3 | **Wire Routing** | Shortest Path (Dijkstra) | Click nodes to build lowest-cost route | -- |
| 4 | **Pattern Sequence** | Pattern Recognition | Identify rule and fill missing number | 10 pattern types |
| 5 | **Code Breaker** | Logical Deduction (CSP) | Mastermind-style code cracking with Wordle colors | -- |
| 6 | **Memory Matrix** | Spatial Memory / Caching | Memorize grid pattern, then reproduce it | -- |
| 7 | **Bit Cipher** | Binary Representation | Toggle bits to match a decimal target | Decode mode (read binary, type decimal) |
| 8 | **Stack Overflow** | Stack (LIFO) | Predict POP output from PUSH/POP sequence | Queue FIFO mode (40%) |
| 9 | **Priority Queue** | Priority Queue / Heap | Click tasks in priority order | Min-priority mode (35%) |
| 10 | **Logic Gates** | Boolean Logic | Set inputs to produce target circuit output | XOR/NAND gates |

### Pattern Sequence Types

| Type | Example | Rule |
|------|---------|------|
| Arithmetic | 3, 7, 11, 15, 19, 23 | Constant difference (+4) |
| Geometric | 2, 6, 18, 54, 162, 486 | Constant ratio (x3) |
| Fibonacci | 2, 3, 5, 8, 13, 21 | Sum of two previous |
| Squares | 4, 9, 16, 25, 36, 49 | n^2 |
| Triangular | 1, 3, 6, 10, 15, 21 | n(n+1)/2 |
| Cubes | 8, 27, 64, 125, 216, 343 | n^3 |
| Powers of 2 | 2, 4, 8, 16, 32, 64 | 2^n |
| Primes | 5, 7, 11, 13, 17, 19 | Prime numbers |
| Alternating | 5, 13, 10, 18, 15, 23 | +d1, -d2, repeating |
| Quadratic | 6, 13, 24, 39, 58, 81 | an^2 + bn + c |

---

## Campaign Structure

The game spans 10 waves across real-world cities, each with unique module combinations and escalating threat levels:

| Wave | City | Region | Threat | Modules |
|------|------|--------|--------|---------|
| 1 | Washington D.C. | North America | LOW | Frequency Lock, Bit Cipher, Pattern Sequence |
| 2 | London | Europe | LOW | Logic Gates, Signal Sorting, Stack Overflow |
| 3 | Paris | Europe | MODERATE | Memory Matrix, Wire Routing, Priority Queue |
| 4 | Tokyo | Asia | MODERATE | Code Breaker, Bit Cipher, Signal Sorting |
| 5 | Cairo | Africa | ELEVATED | Stack Overflow, Pattern Sequence, Wire Routing |
| 6 | Moscow | Europe | ELEVATED | Priority Queue, Logic Gates, Frequency Lock |
| 7 | Mumbai | Asia | HIGH | Code Breaker, Memory Matrix, Stack Overflow |
| 8 | Sydney | Oceania | HIGH | Bit Cipher, Priority Queue, Pattern Sequence |
| 9 | Rio de Janeiro | South America | SEVERE | Wire Routing, Logic Gates, Memory Matrix |
| 10 | Pyongyang | Asia | CRITICAL | Frequency Lock, Code Breaker, Signal Sorting |

Every module type appears exactly **3 times** across the campaign.

---

## Adaptive Difficulty

The difficulty engine tracks player performance and adjusts parameters wave-by-wave:

```
Performance Efficiency = 0.5 * (time_ratio) + 0.5 * (mistake_ratio)
   where time_ratio   = 1 - (time_used / timer_total)
         mistake_ratio = 1 - (mistakes / max_mistakes)
```

| Parameter | Wave 1 | Wave 5 | Wave 10 | Scaling |
|-----------|--------|--------|---------|---------|
| Timer (s) | 150 | 110 | 60 | -10s/wave (min 60) |
| Stability | 100 | 80 | 55 | -5/wave (min 50) |
| Penalty/error | 10 | 16 | 24 | +1.5/wave |
| Search range | 50 | 192 | 1000 | x1.4/wave |
| Sort elements | 5 | 7 | 10 | +0.5/wave (max 10) |
| Graph nodes | 5 | 7 | 9 | +0.4/wave (max 9) |

**Adaptive bonuses** (efficiency > 0.7): +10s timer, +1 sort element, +1 graph node

**Mercy mode** (efficiency < 0.3): Repeat previous wave's difficulty parameters

---

## Module Variants

To reduce repetitiveness across waves, modules activate alternate modes on later waves:

```
Module appears in wave -> Check variant activation -> Different puzzle experience

Frequency Lock:  Wave 4+, 40% chance -> Hot/Cold mode (distance feedback, no direction)
Bit Cipher:      Wave 3+, 40% chance -> Decode mode (read binary, type decimal)
Stack Overflow:  Any wave, 40% chance -> Queue FIFO mode (dequeue from front)
Signal Sorting:  Any wave, 30% chance -> Descending sort
Priority Queue:  Any wave, 35% chance -> Min-priority mode (lowest first)
Logic Gates:     Any wave, always     -> XOR and NAND gates in circuit pool
Pattern Sequence: Any wave, always    -> 10 pattern types (vs. original 4)
```

---

## AI Commentary System

The game features a dual-mode text generation system:

```
Player Action -> LLMService -> [Backend available?]
                                    |           |
                                   YES          NO
                                    |           |
                              Async HTTP    Return fallback
                              POST to       text immediately
                              FastAPI        |
                                    |        |
                              Parse JSON     |
                              emit signal    |
                                    |        |
                              Update UI  <---+
                              (hot-swap)
```

**Text categories**:
- **Mission briefing**: Campaign narrative (opening + per-city)
- **Module hints**: Algorithm-specific guidance (3-6 hints per module type)
- **Real-time commentary**: Reactions to wrong actions, module solves, time/stability warnings
- **Results summary**: Post-game analysis referencing algorithms used

The fallback text library covers all categories with multiple randomized variants, ensuring the game is fully playable offline.

---

## Visual Systems

### Bomb Visual
Procedurally drawn bomb with 11 rendering layers:
- Ambient glow, metallic body with rivets and seams
- Wire veins with sine-wave pulsing (cyan -> red at low stability)
- Pulsing core, nozzle, burning fuse that shrinks with timer
- Animated flame with spark and smoke particles
- LED status indicators, digital timer display
- Stability arc indicator (green -> orange -> red)
- Explosion sequence: flash, fireball, shockwave, debris, smoke, "BOOM!" text
- Defused state: green tint, checkmark, pulsing "DEFUSED" text

### Tech Background
Animated sci-fi backdrop with:
- Moving grid lines (shift from cyan to red at high danger)
- 40 floating particles with sine-wave drift
- 8 Matrix-style data streams (binary + katakana characters)
- HUD corner brackets, city watermark
- Scanline sweep effect

### Screen Effects (Shader)
Post-processing overlay via CanvasLayer:
- CRT vignette + scanlines
- Chromatic aberration on damage
- Screen flash (red=damage, white=explosion, green=defuse)
- Procedural noise grain

---

## Getting Started

### Prerequisites

- **Godot 4.6+** (uses `gl_compatibility` renderer)
- **Python 3.13+** with `uv` (optional, for LLM backend)

### Run the Game

```bash
# Option 1: Godot Editor
# Open Godot -> Import -> Select game/ folder -> Press F5

# Option 2: Command line (if Godot is in PATH)
cd game
godot --path .
```

### Run the Backend (Optional)

```bash
cd backend
cp ../.env.example ../.env   # Add your OpenAI API key
uv sync
uv run python main.py        # Starts on http://127.0.0.1:8000
```

The game auto-detects the backend at startup. If unavailable, all text falls back to the built-in library.

---

## Deployment

### Web (Recommended for research)

1. In Godot: **Project -> Export -> Add -> Web**
2. Export as `index.html`
3. Zip all output files
4. Upload to [itch.io](https://itch.io) (free):
   - Set "Kind of project" to **HTML**
   - Check **"This file will be played in the browser"**
   - Viewport: **1280 x 720**

The QUIT button auto-hides on web builds. The LLM backend uses offline fallback text in web deployments.

### Desktop

Export from Godot for Windows (.exe), macOS (.dmg), or Linux (.x86_64). Distribute via GitHub Releases or direct download.

---

## Project Structure

```
Project 2/
|-- game/                          # Godot 4 project
|   |-- project.godot              # Engine config (autoloads, display, input)
|   |-- assets/
|   |   +-- world_map.png          # Natural Earth equirectangular map
|   |-- autoload/                  # Global singletons
|   |   |-- game_state.gd          # Runtime state, signals, timer
|   |   |-- difficulty_manager.gd  # Adaptive difficulty engine
|   |   |-- wave_data.gd           # 10 cities, module assignments
|   |   +-- llm_service.gd         # AI text (async HTTP + fallback)
|   |-- modules/                   # Module scene files (.tscn)
|   |-- scenes/                    # Screen scene files (.tscn)
|   +-- scripts/                   # All GDScript source
|       |-- base_module.gd         # Abstract base for puzzle modules
|       |-- bomb_game.gd           # Main gameplay loop
|       |-- bomb_visual.gd         # Procedural bomb rendering
|       |-- tech_background.gd     # Animated sci-fi backdrop
|       |-- screen_effects.gd      # Shader post-processing
|       |-- world_map.gd           # Inter-wave map screen
|       |-- result_screen.gd       # Victory/failure with campaign summary
|       |-- main_menu.gd           # Title screen
|       |-- opening_briefing.gd    # Campaign intro narrative
|       |-- briefing_overlay.gd    # Typewriter text overlay
|       |-- frequency_lock_module.gd
|       |-- signal_sorting_module.gd
|       |-- wire_routing_module.gd
|       |-- pattern_sequence_module.gd
|       |-- code_breaker_module.gd
|       |-- memory_matrix_module.gd
|       |-- bit_cipher_module.gd
|       |-- stack_overflow_module.gd
|       |-- priority_queue_module.gd
|       +-- logic_gates_module.gd
|
|-- backend/                       # Python FastAPI server
|   |-- main.py                    # API endpoints + OpenAI integration
|   |-- pyproject.toml             # Dependencies (fastapi, openai, uvicorn)
|   +-- uv.lock                    # Locked dependency versions
|
|-- .env.example                   # Template for API keys
+-- README.md                      # This file
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Game Engine | Godot 4.6 (GDScript, `gl_compatibility` renderer) |
| Backend | Python 3.13, FastAPI, OpenAI API |
| Package Manager | uv (Python), Godot asset system |
| Deployment | Web (HTML5/WebAssembly), Desktop (native) |
| Hosting | itch.io (web), GitHub Releases (desktop) |
| Version Control | Git |

---

## License

This project is part of academic research at the University of Ottawa. Contact the author for licensing inquiries.
