# Bomb Defusal: Algorithm Mode — Design Spec

## Overview

A 2D serious game built in Godot 4 (GDScript) where the player defuses a bomb by solving 3 algorithm-inspired puzzle modules under time pressure. Includes a Python FastAPI backend for live OpenAI LLM integration with offline fallback.

## Project Structure

```
Project 2/
├── game/                          # Godot 4 project root
│   ├── project.godot
│   ├── scenes/
│   │   ├── main_menu.tscn
│   │   ├── bomb_game.tscn
│   │   └── result_screen.tscn
│   ├── modules/
│   │   ├── frequency_lock_module.tscn
│   │   ├── signal_sorting_module.tscn
│   │   └── wire_routing_module.tscn
│   ├── scripts/
│   │   ├── main_menu.gd
│   │   ├── bomb_game.gd
│   │   ├── result_screen.gd
│   │   ├── base_module.gd
│   │   ├── frequency_lock_module.gd
│   │   ├── signal_sorting_module.gd
│   │   └── wire_routing_module.gd
│   ├── autoload/
│   │   ├── game_state.gd
│   │   └── llm_service.gd
│   └── themes/
│       └── bomb_theme.tres
├── backend/
│   ├── main.py                    # FastAPI server
│   ├── pyproject.toml
│   └── .python-version
├── .env                           # OPENAI_API_KEY (gitignored)
├── .gitignore
└── README.md
```

## Architecture

### Approach: Scene-per-module with Autoload State

- Each puzzle module is a standalone scene + script extending `BaseModule`
- `GameState` autoload singleton persists timer, stability, scores across scenes
- `LLMService` autoload singleton handles LLM integration with fallback
- Scene transitions: MainMenu → BombGame → ResultScreen → MainMenu

### BaseModule Interface

`class_name BaseModule extends PanelContainer`

Properties:
- `module_name: String`
- `is_solved: bool = false`
- `mistakes: int = 0`
- `time_started: float`

Methods:
- `reset_module()` — reset to initial state
- `apply_hint()` — request and display contextual hint from LLM service
- `complete_module()` — mark solved, emit signal, visual feedback
- `record_wrong_action()` — increment mistakes, emit signal

Signals:
- `module_solved(module_name: String)`
- `wrong_action(module_name: String)`

## Game Flow & State

### GameState Autoload

- `timer_total: float = 120.0`
- `timer_remaining: float`
- `stability: int = 100`
- `stability_penalty: int = 10`
- `mistakes: int = 0`
- `modules_solved: int = 0`
- `module_results: Array[Dictionary]` — per-module performance
- `game_outcome: String` — "defused" / "exploded_timer" / "exploded_stability"

### Game Loop (BombGame)

1. `_ready()`: reset GameState, instantiate 3 modules, start timer
2. `_process(delta)`: tick timer, update UI, check lose conditions
3. Module emits `module_solved` → increment count, check win
4. Module emits `wrong_action` → decrease stability, increment mistakes
5. All 3 solved → win → ResultScreen
6. Timer=0 OR stability=0 → lose → ResultScreen

### ResultScreen

Reads GameState to display:
- Win/lose outcome with appropriate visuals
- Time remaining (or 0)
- Total mistakes
- Per-module algorithm explanation (from LLM or fallback)
- Replay and Main Menu buttons

## Module Designs

### A. Frequency Lock (Binary Search)

- Random target 1–100
- SpinBox input + Submit button
- Feedback: "TOO HIGH" (red) / "TOO LOW" (blue)
- Correct guess → solved
- Each wrong guess → wrong_action signal
- Optimal: ~7 guesses (log2 100)
- Post-game: teaches binary search

### B. Signal Sorting (Sorting)

- 6 random values (10–99) displayed as clickable buttons
- Click two buttons to swap them
- Every swap counts as an action. If the total inversion count after the swap is >= the count before, it's a wrong_action (the player made a non-improving move)
- Array sorted ascending → solved
- Already-sorted positions highlight green
- Post-game: teaches sorting and inversion counting

### C. Wire Routing (Shortest Path)

- 6 nodes, ~8 edges with random costs (1–9)
- Nodes as clickable circles, edges as lines with cost labels
- Source node (green), target node (red)
- Click nodes sequentially to build path
- "Reset Path" button (no penalty)
- "Confirm Route" → if cost matches Dijkstra optimal → solved, else wrong_action + reset
- Graph generated with guaranteed connectivity
- Post-game: teaches weighted shortest path

## UI & Visual Design

### Color Palette

- Background: `#0a0e17` (near-black navy)
- Panel surfaces: `#141b2d` (dark slate)
- Primary accent: `#00e5ff` (cyan)
- Warning: `#ff6f00` (amber)
- Danger: `#ff1744` (red)
- Success: `#00e676` (green)
- Text: `#e0e0e0` (light gray)

### Timer States

- Normal (>30s): cyan
- Warning (10–30s): amber, gentle pulse
- Critical (<10s): red, fast pulse

### Stability Bar

- ProgressBar: green → amber → red based on value
- Below 30: bar flashes

### Layout

```
┌─────────────────────────────────────────────┐
│  BOMB DEFUSAL SYSTEM            ██ 01:42 ██ │
│  Stability: [████████████░░░░] 70%          │
│  Mission: "Disarm the device before..."     │
├──────────┬──────────┬───────────────────────┤
│ FREQ     │ SIGNAL   │ WIRE                  │
│ LOCK     │ SORT     │ ROUTE                 │
│ [module] │ [module] │ [module]              │
├──────────┴──────────┴───────────────────────┤
│  Status: "Module 1 of 3 remaining"          │
└─────────────────────────────────────────────┘
```

## LLM Integration

### Architecture

```
Godot (HTTPRequest) → FastAPI backend (localhost:8000) → OpenAI API (gpt-4o-mini)
```

### Backend Endpoints

```
GET  /health                    → { "status": "ok" }
POST /api/mission-briefing      → { "text": "..." }
POST /api/module-hint           → { "text": "..." }  (body: module_name, state)
POST /api/results-summary       → { "text": "..." }  (body: performance_data)
```

### GDScript LLMService Behavior

1. On game start, check `GET /health`
2. If reachable → `use_llm = true`
3. If not → `use_llm = false`, use hardcoded fallback text
4. All calls async via HTTPRequest, 5s timeout
5. Signal `llm_response_received(context, text)` updates UI
6. Game never blocks — fallback shown immediately, replaced when LLM responds

### Backend Stack

- Python 3.13+, FastAPI, uvicorn, openai, python-dotenv
- Model: gpt-4o-mini
- `.env` at project root: `OPENAI_API_KEY=sk-...`

### Fallback Text

Each method has 3–5 hardcoded variants randomly selected:
- Mission briefings: narrative flavor text
- Module hints: algorithm-teaching hints per module
- Result summaries: templated with performance data

## Gameplay Rules

- Timer: 120 seconds
- Stability: starts at 100, -10 per wrong action
- Timer=0 → explosion (lose)
- Stability=0 → explosion (lose)
- All 3 modules solved → defused (win)
- Wrong actions: wrong guess, non-improving swap, wrong path

## Technical Constraints

- Godot 4.x, GDScript only
- No external art assets — Godot UI elements, shapes, colors
- Control-based UI nodes
- Monospace/system fonts only
- Must run as MVP without backend (fallback mode)
