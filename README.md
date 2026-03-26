# Bomb Defusal: Algorithm Mode

A 2D serious game built in Godot 4 where players defuse a bomb by solving algorithm-inspired puzzle modules under time pressure.

## Project Structure

```
game/      — Godot 4 project (GDScript)
backend/   — Python FastAPI server for LLM integration
```

## Quick Start

### Game (Godot)

1. Open Godot 4.3+
2. Import the `game/` folder as a project
3. Press F5 to run

### Backend (optional — for AI-generated text)

```bash
cd backend
cp ../.env.example ../.env   # Add your OpenAI API key
uv sync
uv run python main.py
```

The game auto-detects the backend. If it's not running, hardcoded fallback text is used.

## Modules

| Module | Algorithm | Mechanic |
|--------|-----------|----------|
| Frequency Lock | Binary Search | Guess a number 1-100 with high/low feedback |
| Signal Sorting | Sorting | Swap elements to sort; non-improving swaps penalized |
| Wire Routing | Shortest Path | Click nodes to build lowest-cost route through a graph |

## Rules

- Timer: 120 seconds
- Stability: 100, -10 per wrong action
- Solve all 3 modules to defuse
- Timer or stability hits 0 → explosion
