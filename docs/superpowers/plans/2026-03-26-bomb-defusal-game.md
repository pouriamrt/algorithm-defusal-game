# Bomb Defusal: Algorithm Mode — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable Godot 4 serious game where players defuse a bomb by solving 3 algorithm-inspired puzzle modules, backed by a Python FastAPI server for live OpenAI LLM integration.

**Architecture:** Monorepo with `game/` (Godot 4, GDScript) and `backend/` (Python FastAPI + OpenAI). Game uses Autoload singletons for state (GameState) and LLM calls (LLMService). Each puzzle module is a standalone scene extending a shared BaseModule class. LLM service auto-detects backend availability and falls back to hardcoded text.

**Tech Stack:** Godot 4.x, GDScript, Python 3.13+, FastAPI, uvicorn, openai, python-dotenv

**Spec:** `docs/superpowers/specs/2026-03-26-bomb-defusal-game-design.md`

---

## File Map

### Repo Root (refactored)

| File | Responsibility |
|------|----------------|
| `.gitignore` | Modify: add Godot ignores, `.env` |
| `README.md` | Modify: project overview with both game/ and backend/ |
| `.env` | Create: `OPENAI_API_KEY=your-key-here` (gitignored) |

### `backend/` (Python FastAPI)

| File | Responsibility |
|------|----------------|
| `backend/pyproject.toml` | Move from root, add FastAPI/openai deps |
| `backend/.python-version` | Move from root |
| `backend/main.py` | Rewrite: FastAPI server with /health, /api/* endpoints |

### `game/` (Godot 4)

| File | Responsibility |
|------|----------------|
| `game/project.godot` | Godot project config, autoload registration |
| `game/autoload/game_state.gd` | Singleton: timer, stability, scores, module results |
| `game/autoload/llm_service.gd` | Singleton: LLM HTTP calls + fallback text |
| `game/scripts/main_menu.gd` | Main menu: start game, quit |
| `game/scripts/bomb_game.gd` | Game scene controller: timer, modules, win/lose |
| `game/scripts/result_screen.gd` | Result display: outcome, stats, explanations |
| `game/scripts/base_module.gd` | Abstract base: signals, shared methods |
| `game/scripts/frequency_lock_module.gd` | Binary search puzzle logic |
| `game/scripts/signal_sorting_module.gd` | Sorting puzzle logic |
| `game/scripts/wire_routing_module.gd` | Shortest path puzzle logic + Dijkstra |
| `game/scenes/main_menu.tscn` | Main menu scene (built in editor or code) |
| `game/scenes/bomb_game.tscn` | Game scene (built in editor or code) |
| `game/scenes/result_screen.tscn` | Result screen scene (built in editor or code) |
| `game/modules/frequency_lock_module.tscn` | Frequency module scene |
| `game/modules/signal_sorting_module.tscn` | Sorting module scene |
| `game/modules/wire_routing_module.tscn` | Wire routing module scene |

---

## Task 1: Refactor Repo Structure

**Files:**
- Move: `main.py` → `backend/main.py`
- Move: `pyproject.toml` → `backend/pyproject.toml`
- Move: `.python-version` → `backend/.python-version`
- Modify: `.gitignore`
- Create: `.env`
- Delete: root `main.py`, root `pyproject.toml`, root `.python-version`

- [ ] **Step 1: Create backend directory and move Python files**

```bash
mkdir -p backend
mv main.py backend/main.py
mv pyproject.toml backend/pyproject.toml
mv .python-version backend/.python-version
```

- [ ] **Step 2: Create game directory structure**

```bash
mkdir -p game/autoload game/scripts game/scenes game/modules game/themes
```

- [ ] **Step 3: Update .gitignore for Godot + .env**

Replace the contents of `.gitignore` with:

```gitignore
# Python
__pycache__/
*.py[oc]
build/
dist/
wheels/
*.egg-info
.venv

# Environment
.env

# Godot
.godot/
*.import
export_presets.cfg
*.translation

# OS
.DS_Store
Thumbs.db
```

- [ ] **Step 4: Create .env template**

Create `.env` at project root:

```
OPENAI_API_KEY=your-key-here
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: restructure into game/ and backend/ subdirectories"
```

---

## Task 2: Python FastAPI Backend

**Files:**
- Modify: `backend/pyproject.toml`
- Rewrite: `backend/main.py`

- [ ] **Step 1: Update pyproject.toml with dependencies**

Replace `backend/pyproject.toml`:

```toml
[project]
name = "bomb-defusal-backend"
version = "0.1.0"
description = "FastAPI backend for Bomb Defusal: Algorithm Mode LLM integration"
readme = "README.md"
requires-python = ">=3.13"
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn>=0.34.0",
    "openai>=1.60.0",
    "python-dotenv>=1.1.0",
]
```

- [ ] **Step 2: Install dependencies**

```bash
cd backend
uv sync
cd ..
```

- [ ] **Step 3: Write the FastAPI server**

Replace `backend/main.py`:

```python
from __future__ import annotations

import os
import random
from typing import Any

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Load .env from project root (one level up)
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "..", ".env"))

app = FastAPI(title="Bomb Defusal LLM Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- OpenAI client (lazy init) ---

_client = None


def _get_client():
    global _client
    if _client is None:
        api_key = os.environ.get("OPENAI_API_KEY", "")
        if not api_key or api_key == "your-key-here":
            raise HTTPException(
                status_code=503,
                detail="OPENAI_API_KEY not configured in .env",
            )
        from openai import OpenAI

        _client = OpenAI(api_key=api_key)
    return _client


def _chat(system_prompt: str, user_prompt: str) -> str:
    client = _get_client()
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        max_tokens=300,
        temperature=0.8,
    )
    return response.choices[0].message.content.strip()


# --- Models ---


class ModuleHintRequest(BaseModel):
    module_name: str
    current_state: dict[str, Any] = {}


class ResultsSummaryRequest(BaseModel):
    game_outcome: str
    timer_remaining: float
    total_mistakes: int
    module_results: list[dict[str, Any]]


# --- Endpoints ---


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/api/mission-briefing")
def mission_briefing():
    system = (
        "You are a dramatic mission briefing narrator for a bomb defusal game. "
        "The player is a technician who must solve algorithm-based puzzles to defuse a bomb. "
        "Write a 2-3 sentence tense, immersive briefing. Keep it short and punchy."
    )
    user = "Generate a new mission briefing for the bomb defusal operation."
    text = _chat(system, user)
    return {"text": text}


@app.post("/api/module-hint")
def module_hint(req: ModuleHintRequest):
    module_descriptions = {
        "Frequency Lock": (
            "a binary-search puzzle where the player guesses a hidden number 1-100 "
            "and gets 'too high' or 'too low' feedback"
        ),
        "Signal Sorting": (
            "a sorting puzzle where the player swaps elements to sort an array, "
            "penalized for swaps that don't reduce inversions"
        ),
        "Wire Routing": (
            "a shortest-path puzzle where the player clicks nodes to build a route "
            "through a weighted graph from source to target"
        ),
    }
    desc = module_descriptions.get(req.module_name, "an algorithm puzzle")
    system = (
        "You are a helpful AI assistant inside a bomb defusal game. "
        "Give the player a short, encouraging hint (1-2 sentences) for the puzzle. "
        "Teach the underlying algorithm concept without giving away the answer. "
        "Be concise and in-character as a support AI."
    )
    state_str = ", ".join(f"{k}: {v}" for k, v in req.current_state.items())
    user = (
        f"The player is working on the '{req.module_name}' module — {desc}. "
        f"Current state: {state_str if state_str else 'just started'}. "
        f"Give a helpful hint."
    )
    text = _chat(system, user)
    return {"text": text}


@app.post("/api/results-summary")
def results_summary(req: ResultsSummaryRequest):
    system = (
        "You are an educational debrief AI for a bomb defusal game that teaches algorithms. "
        "Summarize the player's performance and explain the algorithm behind each module. "
        "Be encouraging, educational, and concise. Use 3-5 sentences total."
    )
    modules_str = "\n".join(
        f"- {m.get('name', '?')}: {m.get('mistakes', 0)} mistakes, "
        f"algorithm: {m.get('algorithm', '?')}"
        for m in req.module_results
    )
    user = (
        f"Game outcome: {req.game_outcome}\n"
        f"Time remaining: {req.timer_remaining:.1f}s\n"
        f"Total mistakes: {req.total_mistakes}\n"
        f"Modules:\n{modules_str}\n\n"
        f"Give a short educational debrief."
    )
    text = _chat(system, user)
    return {"text": text}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000)
```

- [ ] **Step 4: Test the backend starts**

```bash
cd backend
uv run python main.py &
# Wait 2 seconds for startup
sleep 2
curl http://localhost:8000/health
# Expected: {"status":"ok"}
# Kill the background server
kill %1
cd ..
```

- [ ] **Step 5: Commit**

```bash
git add backend/
git commit -m "feat: add FastAPI backend with OpenAI LLM endpoints"
```

---

## Task 3: Godot Project Setup + GameState Autoload

**Files:**
- Create: `game/project.godot`
- Create: `game/autoload/game_state.gd`

- [ ] **Step 1: Create project.godot**

Create `game/project.godot`:

```ini
; Engine configuration file.
; It's best edited using the editor UI and target Godot 4.x.

[application]

config/name="Bomb Defusal: Algorithm Mode"
run/main_scene="res://scenes/main_menu.tscn"
config/features=PackedStringArray("4.3")

[autoload]

GameState="*res://autoload/game_state.gd"
LLMService="*res://autoload/llm_service.gd"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"

[rendering]

renderer/rendering_method="gl_compatibility"
```

- [ ] **Step 2: Write game_state.gd**

Create `game/autoload/game_state.gd`:

```gdscript
extends Node
## Global game state singleton. Persists across scene transitions.
## Tracks timer, stability, module completion, and per-module results.

signal stability_changed(new_value: int)
signal timer_updated(remaining: float)
signal game_over(outcome: String)

# Configuration
var timer_total: float = 120.0
var stability_max: int = 100
var stability_penalty: int = 10

# Runtime state
var timer_remaining: float = 120.0
var stability: int = 100
var mistakes: int = 0
var modules_solved: int = 0
var modules_total: int = 3
var game_outcome: String = ""  # "defused", "exploded_timer", "exploded_stability"
var module_results: Array[Dictionary] = []
var is_game_active: bool = false


func reset() -> void:
	"""Reset all state for a new game."""
	timer_remaining = timer_total
	stability = stability_max
	mistakes = 0
	modules_solved = 0
	game_outcome = ""
	module_results.clear()
	is_game_active = true


func record_wrong_action() -> void:
	"""Called when a module reports a wrong action."""
	if not is_game_active:
		return
	mistakes += 1
	stability = max(0, stability - stability_penalty)
	stability_changed.emit(stability)
	if stability <= 0:
		game_outcome = "exploded_stability"
		is_game_active = false
		game_over.emit(game_outcome)


func record_module_solved(result: Dictionary) -> void:
	"""Called when a module is completed. result has: name, mistakes, algorithm."""
	if not is_game_active:
		return
	modules_solved += 1
	module_results.append(result)
	if modules_solved >= modules_total:
		game_outcome = "defused"
		is_game_active = false
		game_over.emit(game_outcome)


func tick_timer(delta: float) -> void:
	"""Called each frame by BombGame._process."""
	if not is_game_active:
		return
	timer_remaining = max(0.0, timer_remaining - delta)
	timer_updated.emit(timer_remaining)
	if timer_remaining <= 0.0:
		game_outcome = "exploded_timer"
		is_game_active = false
		game_over.emit(game_outcome)
```

- [ ] **Step 3: Commit**

```bash
git add game/project.godot game/autoload/game_state.gd
git commit -m "feat: add Godot project config and GameState autoload"
```

---

## Task 4: LLMService Autoload

**Files:**
- Create: `game/autoload/llm_service.gd`

- [ ] **Step 1: Write llm_service.gd**

Create `game/autoload/llm_service.gd`:

```gdscript
extends Node
## LLM integration service. Calls FastAPI backend when available,
## falls back to hardcoded text when backend is unreachable.

signal llm_response_received(context: String, text: String)

const BACKEND_URL: String = "http://127.0.0.1:8000"
const TIMEOUT_SEC: float = 5.0

var use_llm: bool = false
var _http: HTTPRequest


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SEC
	add_child(_http)
	_check_backend_health()


func _check_backend_health() -> void:
	"""Try to reach the backend. Sets use_llm accordingly."""
	var health_http := HTTPRequest.new()
	health_http.timeout = 3.0
	add_child(health_http)
	health_http.request_completed.connect(
		func(_result, response_code, _headers, _body):
			use_llm = (response_code == 200)
			if use_llm:
				print("[LLMService] Backend connected — LLM mode active")
			else:
				print("[LLMService] Backend unreachable — using fallback text")
			health_http.queue_free()
	)
	var err := health_http.request(BACKEND_URL + "/health")
	if err != OK:
		use_llm = false
		health_http.queue_free()


# --- Public API ---


func get_mission_briefing() -> String:
	"""Returns fallback immediately. If LLM is active, fires async request
	and emits llm_response_received('mission_briefing', text) when done."""
	var fallback := _fallback_mission_briefing()
	if use_llm:
		_post_request("/api/mission-briefing", {}, "mission_briefing")
	return fallback


func get_module_hint(module_name: String, current_state: Dictionary) -> String:
	"""Returns fallback hint immediately. Async LLM result emitted if available."""
	var fallback := _fallback_module_hint(module_name)
	if use_llm:
		_post_request(
			"/api/module-hint",
			{"module_name": module_name, "current_state": current_state},
			"module_hint"
		)
	return fallback


func get_results_summary(performance_data: Dictionary) -> String:
	"""Returns fallback summary immediately. Async LLM result emitted if available."""
	var fallback := _fallback_results_summary(performance_data)
	if use_llm:
		_post_request("/api/results-summary", performance_data, "results_summary")
	return fallback


# --- HTTP helpers ---


func _post_request(endpoint: String, body: Dictionary, context: String) -> void:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SEC
	add_child(req)
	req.request_completed.connect(
		func(_result, response_code, _headers, response_body):
			if response_code == 200:
				var json = JSON.parse_string(response_body.get_string_from_utf8())
				if json and json.has("text"):
					llm_response_received.emit(context, json["text"])
			req.queue_free()
	)
	var json_str := JSON.stringify(body)
	var headers := ["Content-Type: application/json"]
	req.request(BACKEND_URL + endpoint, headers, HTTPClient.METHOD_POST, json_str)


# --- Fallback text ---


func _fallback_mission_briefing() -> String:
	var briefings := [
		"ALERT: A rogue AI has armed an algorithmic explosive in Sector 7-G. You have 120 seconds to solve its puzzle locks before detonation. Trust your instincts, technician.",
		"INCOMING TRANSMISSION: An unstable device has been detected in the server core. Three encrypted modules stand between you and safety. The clock is ticking.",
		"PRIORITY ONE: A cascade failure bomb has been planted in the neural network hub. Solve the algorithmic locks to prevent total system collapse. Move fast.",
		"WARNING: Hostile code has armed a logic bomb in the mainframe. Only a skilled technician can crack its three cipher modules in time. You're our last hope.",
		"URGENT: An encrypted detonator is counting down in the quantum relay station. Three algorithm puzzles guard the kill switch. Precision over speed, technician.",
	]
	return briefings[randi() % briefings.size()]


func _fallback_module_hint(module_name: String) -> String:
	var hints := {
		"Frequency Lock": [
			"Think about cutting the search space in half with each guess.",
			"What if you always guessed the middle of the remaining range?",
			"The optimal strategy eliminates half the possibilities every time.",
		],
		"Signal Sorting": [
			"Look for the largest out-of-place element and move it toward its correct position.",
			"Count how many pairs are in the wrong order — try to reduce that number with each swap.",
			"Focus on making progress: each swap should bring you closer to sorted order.",
		],
		"Wire Routing": [
			"The shortest path isn't always the one with fewest hops — watch the edge weights.",
			"Try to find the path where the sum of all edge costs is minimized.",
			"Compare routes by adding up their total cost, not just counting steps.",
		],
	}
	var module_hints: Array = hints.get(module_name, ["Think carefully about your next move."])
	return module_hints[randi() % module_hints.size()]


func _fallback_results_summary(performance_data: Dictionary) -> String:
	var outcome: String = performance_data.get("game_outcome", "unknown")
	var time_left: float = performance_data.get("timer_remaining", 0.0)
	var total_mistakes: int = performance_data.get("total_mistakes", 0)

	if outcome == "defused":
		return (
			"Excellent work, technician! You defused the device with %.1fs remaining and %d mistake(s). "
			% [time_left, total_mistakes]
			+ "The Frequency Lock tested binary search — halving the search space each guess. "
			+ "Signal Sorting explored how comparing and swapping elements brings order from chaos. "
			+ "Wire Routing challenged you to find the lowest-cost path through a weighted graph, "
			+ "the core idea behind Dijkstra's algorithm."
		)
	else:
		return (
			"The device detonated. You made %d mistake(s). " % total_mistakes
			+ "Review the algorithms: binary search (Frequency Lock) halves the search space, "
			+ "sorting (Signal Sort) reduces inversions, and shortest path (Wire Route) minimizes "
			+ "total edge cost. Study these patterns and try again!"
		)
```

- [ ] **Step 2: Commit**

```bash
git add game/autoload/llm_service.gd
git commit -m "feat: add LLMService autoload with OpenAI backend + fallback"
```

---

## Task 5: BaseModule Abstract Class

**Files:**
- Create: `game/scripts/base_module.gd`

- [ ] **Step 1: Write base_module.gd**

Create `game/scripts/base_module.gd`:

```gdscript
class_name BaseModule
extends PanelContainer
## Abstract base class for all bomb defusal puzzle modules.
## Each module extends this and implements its own puzzle logic.

signal module_solved(module_name: String)
signal wrong_action(module_name: String)

## Display name shown in the module header
@export var module_name: String = "Module"

## Algorithm name for the results screen
@export var algorithm_name: String = "Algorithm"

## Whether this module has been solved
var is_solved: bool = false

## Number of wrong actions in this module
var mistakes: int = 0

## Timestamp when module was first interacted with
var time_started: float = 0.0

## Reference to the header label (set by subclasses)
var _header_label: Label = null

## Reference to the hint label (set by subclasses)
var _hint_label: Label = null


func _ready() -> void:
	# Set up base panel styling
	custom_minimum_size = Vector2(350, 400)
	reset_module()


func reset_module() -> void:
	"""Override in subclass. Reset puzzle to initial state."""
	is_solved = false
	mistakes = 0
	time_started = 0.0


func complete_module() -> void:
	"""Mark module as solved and emit signal."""
	if is_solved:
		return
	is_solved = true
	if _header_label:
		_header_label.text = module_name + "  [SOLVED]"
	# Visual feedback — turn header green
	_set_header_color(Color("#00e676"))
	module_solved.emit(module_name)


func record_wrong_action() -> void:
	"""Record a wrong action and emit signal."""
	mistakes += 1
	wrong_action.emit(module_name)


func apply_hint() -> void:
	"""Request and display a hint from LLMService."""
	var state := get_module_state()
	var hint_text: String = LLMService.get_module_hint(module_name, state)
	if _hint_label:
		_hint_label.text = hint_text
	# Listen for async LLM update
	if not LLMService.llm_response_received.is_connected(_on_llm_hint):
		LLMService.llm_response_received.connect(_on_llm_hint)


func _on_llm_hint(context: String, text: String) -> void:
	if context == "module_hint" and _hint_label:
		_hint_label.text = text


func get_module_state() -> Dictionary:
	"""Override in subclass. Return current puzzle state for hints."""
	return {"module_name": module_name, "mistakes": mistakes}


func get_result() -> Dictionary:
	"""Return result data for the results screen."""
	return {
		"name": module_name,
		"mistakes": mistakes,
		"algorithm": algorithm_name,
	}


func _set_header_color(color: Color) -> void:
	"""Utility: change the header panel color. Override if header structure differs."""
	pass


func _start_timer_if_needed() -> void:
	"""Call this on first player interaction."""
	if time_started == 0.0:
		time_started = Time.get_ticks_msec() / 1000.0
```

- [ ] **Step 2: Commit**

```bash
git add game/scripts/base_module.gd
git commit -m "feat: add BaseModule abstract class for puzzle modules"
```

---

## Task 6: Frequency Lock Module (Binary Search)

**Files:**
- Create: `game/scripts/frequency_lock_module.gd`
- Create: `game/modules/frequency_lock_module.tscn`

- [ ] **Step 1: Write frequency_lock_module.gd**

Create `game/scripts/frequency_lock_module.gd`:

```gdscript
extends BaseModule
## Frequency Lock Module — Binary Search puzzle.
## Player guesses a hidden number 1-100, getting "too high"/"too low" feedback.

var _target: int = 0
var _guess_count: int = 0
var _range_low: int = 1
var _range_high: int = 100

# UI references (built in _ready)
var _spinbox: SpinBox
var _submit_btn: Button
var _feedback_label: Label
var _range_label: Label
var _guess_count_label: Label


func _ready() -> void:
	module_name = "Frequency Lock"
	algorithm_name = "Binary Search"
	super._ready()
	_build_ui()
	reset_module()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Header
	_header_label = Label.new()
	_header_label.text = module_name
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_header_label)

	# Separator
	vbox.add_child(HSeparator.new())

	# Range display
	_range_label = Label.new()
	_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_range_label)

	# Guess input row
	var input_row := HBoxContainer.new()
	input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(input_row)

	_spinbox = SpinBox.new()
	_spinbox.min_value = 1
	_spinbox.max_value = 100
	_spinbox.value = 50
	_spinbox.custom_minimum_size = Vector2(100, 0)
	input_row.add_child(_spinbox)

	_submit_btn = Button.new()
	_submit_btn.text = "SUBMIT"
	_submit_btn.pressed.connect(_on_submit)
	input_row.add_child(_submit_btn)

	# Feedback
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 20)
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_feedback_label)

	# Guess count
	_guess_count_label = Label.new()
	_guess_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guess_count_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_guess_count_label)

	# Hint
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(_hint_label)

	# Hint button
	var hint_btn := Button.new()
	hint_btn.text = "REQUEST HINT"
	hint_btn.pressed.connect(apply_hint)
	vbox.add_child(hint_btn)


func reset_module() -> void:
	super.reset_module()
	_target = randi_range(1, 100)
	_guess_count = 0
	_range_low = 1
	_range_high = 100
	if _feedback_label:
		_feedback_label.text = "Find the safe frequency"
		_feedback_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_range_label.text = "Range: [1 — 100]"
		_guess_count_label.text = "Guesses: 0"
		_hint_label.text = ""
		_spinbox.value = 50
		_submit_btn.disabled = false


func _on_submit() -> void:
	if is_solved:
		return
	_start_timer_if_needed()

	var guess: int = int(_spinbox.value)
	_guess_count += 1
	_guess_count_label.text = "Guesses: %d" % _guess_count

	if guess == _target:
		_feedback_label.text = "FREQUENCY LOCKED!"
		_feedback_label.add_theme_color_override("font_color", Color("#00e676"))
		_submit_btn.disabled = true
		complete_module()
	elif guess < _target:
		_feedback_label.text = "TOO LOW"
		_feedback_label.add_theme_color_override("font_color", Color("#42a5f5"))
		_range_low = max(_range_low, guess + 1)
		_range_label.text = "Range: [%d — %d]" % [_range_low, _range_high]
		record_wrong_action()
	else:
		_feedback_label.text = "TOO HIGH"
		_feedback_label.add_theme_color_override("font_color", Color("#ff1744"))
		_range_high = min(_range_high, guess - 1)
		_range_label.text = "Range: [%d — %d]" % [_range_low, _range_high]
		record_wrong_action()


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"guesses": _guess_count,
		"range_low": _range_low,
		"range_high": _range_high,
		"mistakes": mistakes,
	}
```

- [ ] **Step 2: Create the .tscn scene file**

Create `game/modules/frequency_lock_module.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/frequency_lock_module.gd" id="1"]

[node name="FrequencyLockModule" type="PanelContainer"]
custom_minimum_size = Vector2(350, 400)
script = ExtResource("1")
```

- [ ] **Step 3: Commit**

```bash
git add game/scripts/frequency_lock_module.gd game/modules/frequency_lock_module.tscn
git commit -m "feat: add Frequency Lock module (binary search puzzle)"
```

---

## Task 7: Signal Sorting Module (Sorting)

**Files:**
- Create: `game/scripts/signal_sorting_module.gd`
- Create: `game/modules/signal_sorting_module.tscn`

- [ ] **Step 1: Write signal_sorting_module.gd**

Create `game/scripts/signal_sorting_module.gd`:

```gdscript
extends BaseModule
## Signal Sorting Module — Sorting puzzle.
## Player swaps elements to sort an array. Non-improving swaps are penalized.

const NUM_ELEMENTS: int = 6

var _values: Array[int] = []
var _selected_index: int = -1
var _swap_count: int = 0

# UI references
var _buttons: Array[Button] = []
var _button_row: HBoxContainer
var _status_label: Label
var _swap_count_label: Label


func _ready() -> void:
	module_name = "Signal Sorting"
	algorithm_name = "Sorting (Inversions)"
	super._ready()
	_build_ui()
	reset_module()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Header
	_header_label = Label.new()
	_header_label.text = module_name
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_header_label)

	vbox.add_child(HSeparator.new())

	# Instructions
	var instr := Label.new()
	instr.text = "Click two values to swap them.\nSort ascending to defuse."
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.add_theme_color_override("font_color", Color("#e0e0e0"))
	instr.add_theme_font_size_override("font_size", 12)
	vbox.add_child(instr)

	# Button row
	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_button_row)

	# Status
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_status_label)

	# Swap count
	_swap_count_label = Label.new()
	_swap_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_swap_count_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_swap_count_label)

	# Hint
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(_hint_label)

	# Hint button
	var hint_btn := Button.new()
	hint_btn.text = "REQUEST HINT"
	hint_btn.pressed.connect(apply_hint)
	vbox.add_child(hint_btn)


func reset_module() -> void:
	super.reset_module()
	_selected_index = -1
	_swap_count = 0
	_generate_values()
	_rebuild_buttons()
	if _status_label:
		_status_label.text = "Select two values to swap"
		_status_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		_swap_count_label.text = "Swaps: 0"
		_hint_label.text = ""


func _generate_values() -> void:
	"""Generate NUM_ELEMENTS random values, ensuring they're not already sorted."""
	_values.clear()
	for i in range(NUM_ELEMENTS):
		_values.append(randi_range(10, 99))
	# Ensure not already sorted
	var sorted_copy := _values.duplicate()
	sorted_copy.sort()
	while _values == sorted_copy:
		_values.shuffle()


func _rebuild_buttons() -> void:
	"""Recreate the button row from current values."""
	for btn in _buttons:
		btn.queue_free()
	_buttons.clear()

	for i in range(_values.size()):
		var btn := Button.new()
		btn.text = str(_values[i])
		btn.custom_minimum_size = Vector2(50, 50)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_button_pressed.bind(i))
		_button_row.add_child(btn)
		_buttons.append(btn)

	_update_button_colors()


func _update_button_colors() -> void:
	"""Highlight sorted-in-place elements green, selected element cyan."""
	var sorted_copy := _values.duplicate()
	sorted_copy.sort()

	for i in range(_buttons.size()):
		if i == _selected_index:
			_buttons[i].add_theme_color_override("font_color", Color("#00e5ff"))
		elif _values[i] == sorted_copy[i]:
			_buttons[i].add_theme_color_override("font_color", Color("#00e676"))
		else:
			_buttons[i].add_theme_color_override("font_color", Color("#e0e0e0"))


func _on_button_pressed(index: int) -> void:
	if is_solved:
		return
	_start_timer_if_needed()

	if _selected_index == -1:
		# First selection
		_selected_index = index
		_update_button_colors()
		_status_label.text = "Now select second value to swap"
	elif _selected_index == index:
		# Deselect
		_selected_index = -1
		_update_button_colors()
		_status_label.text = "Select two values to swap"
	else:
		# Perform swap
		var inversions_before := _count_inversions()
		var temp: int = _values[_selected_index]
		_values[_selected_index] = _values[index]
		_values[index] = temp
		var inversions_after := _count_inversions()

		_swap_count += 1
		_swap_count_label.text = "Swaps: %d" % _swap_count
		_selected_index = -1

		if inversions_after >= inversions_before:
			# Non-improving swap — penalty
			_status_label.text = "Bad swap! Inversions not reduced."
			_status_label.add_theme_color_override("font_color", Color("#ff1744"))
			record_wrong_action()
		else:
			_status_label.text = "Good swap! Inversions reduced."
			_status_label.add_theme_color_override("font_color", Color("#00e676"))

		# Update buttons with new values
		for i in range(_buttons.size()):
			_buttons[i].text = str(_values[i])
		_update_button_colors()

		# Check if sorted
		if _is_sorted():
			_status_label.text = "SIGNAL SORTED!"
			_status_label.add_theme_color_override("font_color", Color("#00e676"))
			complete_module()


func _count_inversions() -> int:
	"""Count the number of inversions in the array."""
	var count := 0
	for i in range(_values.size()):
		for j in range(i + 1, _values.size()):
			if _values[i] > _values[j]:
				count += 1
	return count


func _is_sorted() -> bool:
	for i in range(_values.size() - 1):
		if _values[i] > _values[i + 1]:
			return false
	return true


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"values": _values.duplicate(),
		"inversions": _count_inversions(),
		"swaps": _swap_count,
		"mistakes": mistakes,
	}
```

- [ ] **Step 2: Create the .tscn scene file**

Create `game/modules/signal_sorting_module.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/signal_sorting_module.gd" id="1"]

[node name="SignalSortingModule" type="PanelContainer"]
custom_minimum_size = Vector2(350, 400)
script = ExtResource("1")
```

- [ ] **Step 3: Commit**

```bash
git add game/scripts/signal_sorting_module.gd game/modules/signal_sorting_module.tscn
git commit -m "feat: add Signal Sorting module (inversion-based sorting puzzle)"
```

---

## Task 8: Wire Routing Module (Shortest Path)

**Files:**
- Create: `game/scripts/wire_routing_module.gd`
- Create: `game/modules/wire_routing_module.tscn`

- [ ] **Step 1: Write wire_routing_module.gd**

Create `game/scripts/wire_routing_module.gd`:

```gdscript
extends BaseModule
## Wire Routing Module — Shortest Path puzzle.
## Player clicks nodes to build a path through a weighted graph.
## Validates against Dijkstra's optimal shortest path.

const NUM_NODES: int = 6
const GRAPH_SIZE: Vector2 = Vector2(300, 280)
const NODE_RADIUS: float = 20.0

var _nodes: Array[Vector2] = []  # positions
var _edges: Array[Dictionary] = []  # {from, to, cost}
var _adjacency: Dictionary = {}  # node_index -> [{to, cost}]
var _source: int = 0
var _target: int = 5
var _optimal_cost: int = 0
var _player_path: Array[int] = []
var _player_cost: int = 0
var _attempt_count: int = 0

# UI references
var _graph_panel: Panel
var _graph_draw: Control
var _path_label: Label
var _cost_label: Label
var _confirm_btn: Button
var _reset_btn: Button


func _ready() -> void:
	module_name = "Wire Routing"
	algorithm_name = "Shortest Path (Dijkstra)"
	super._ready()
	_build_ui()
	reset_module()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header
	_header_label = Label.new()
	_header_label.text = module_name
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 18)
	_header_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_header_label)

	vbox.add_child(HSeparator.new())

	# Graph drawing area
	_graph_panel = Panel.new()
	_graph_panel.custom_minimum_size = GRAPH_SIZE
	vbox.add_child(_graph_panel)

	_graph_draw = Control.new()
	_graph_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_graph_draw.draw.connect(_on_draw)
	_graph_draw.gui_input.connect(_on_graph_input)
	_graph_panel.add_child(_graph_draw)

	# Path display
	_path_label = Label.new()
	_path_label.text = "Path: (click nodes)"
	_path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_path_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_path_label)

	# Cost display
	_cost_label = Label.new()
	_cost_label.text = "Cost: 0"
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_cost_label)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_confirm_btn = Button.new()
	_confirm_btn.text = "CONFIRM ROUTE"
	_confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(_confirm_btn)

	_reset_btn = Button.new()
	_reset_btn.text = "RESET PATH"
	_reset_btn.pressed.connect(_on_reset_path)
	btn_row.add_child(_reset_btn)

	# Hint
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(_hint_label)

	# Hint button
	var hint_btn := Button.new()
	hint_btn.text = "REQUEST HINT"
	hint_btn.pressed.connect(apply_hint)
	vbox.add_child(hint_btn)


func reset_module() -> void:
	super.reset_module()
	_player_path.clear()
	_player_cost = 0
	_attempt_count = 0
	_generate_graph()
	_compute_shortest_path()
	if _path_label:
		_update_path_display()
		_hint_label.text = ""
		_confirm_btn.disabled = false
		_graph_draw.queue_redraw()


func _generate_graph() -> void:
	"""Generate node positions and edges with guaranteed connectivity."""
	_nodes.clear()
	_edges.clear()
	_adjacency.clear()

	# Place nodes in a grid-like pattern with some randomness
	var cols: int = 3
	var rows: int = 2
	var cell_w: float = GRAPH_SIZE.x / cols
	var cell_h: float = GRAPH_SIZE.y / rows
	for r in range(rows):
		for c in range(cols):
			var x: float = cell_w * (c + 0.5) + randf_range(-20, 20)
			var y: float = cell_h * (r + 0.5) + randf_range(-15, 15)
			_nodes.append(Vector2(x, y))

	# Initialize adjacency
	for i in range(NUM_NODES):
		_adjacency[i] = []

	# Ensure connectivity with a spanning path: 0→1→2→...→5
	for i in range(NUM_NODES - 1):
		var cost: int = randi_range(1, 9)
		_add_edge(i, i + 1, cost)

	# Add extra edges for variety (some shortcuts, some traps)
	var extra_edges := [[0, 2], [0, 3], [1, 4], [2, 5], [3, 5], [1, 3]]
	extra_edges.shuffle()
	var extras_to_add: int = randi_range(2, 4)
	for i in range(min(extras_to_add, extra_edges.size())):
		var pair: Array = extra_edges[i]
		if not _has_edge(pair[0], pair[1]):
			var cost: int = randi_range(1, 9)
			_add_edge(pair[0], pair[1], cost)


func _add_edge(from: int, to: int, cost: int) -> void:
	_edges.append({"from": from, "to": to, "cost": cost})
	_adjacency[from].append({"to": to, "cost": cost})
	_adjacency[to].append({"to": from, "cost": cost})


func _has_edge(from: int, to: int) -> bool:
	for edge in _edges:
		if (edge["from"] == from and edge["to"] == to) or \
		   (edge["from"] == to and edge["to"] == from):
			return true
	return false


func _compute_shortest_path() -> void:
	"""Dijkstra's algorithm to find optimal cost from source to target."""
	var dist: Array[int] = []
	var visited: Array[bool] = []
	for i in range(NUM_NODES):
		dist.append(999999)
		visited.append(false)
	dist[_source] = 0

	for _i in range(NUM_NODES):
		# Find unvisited node with smallest distance
		var u: int = -1
		var min_d: int = 999999
		for v in range(NUM_NODES):
			if not visited[v] and dist[v] < min_d:
				min_d = dist[v]
				u = v
		if u == -1:
			break
		visited[u] = true
		# Relax neighbors
		for neighbor in _adjacency[u]:
			var v: int = neighbor["to"]
			var w: int = neighbor["cost"]
			if dist[u] + w < dist[v]:
				dist[v] = dist[u] + w

	_optimal_cost = dist[_target]


func _on_graph_input(event: InputEvent) -> void:
	if is_solved:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_start_timer_if_needed()
		# Check which node was clicked
		for i in range(_nodes.size()):
			if event.position.distance_to(_nodes[i]) <= NODE_RADIUS + 5:
				_handle_node_click(i)
				break


func _handle_node_click(node_index: int) -> void:
	if _player_path.is_empty():
		# Must start from source
		if node_index != _source:
			return
		_player_path.append(node_index)
	else:
		var last: int = _player_path[-1]
		if node_index == last:
			return
		# Check if edge exists between last and clicked node
		var edge_cost: int = _get_edge_cost(last, node_index)
		if edge_cost < 0:
			return  # No edge — ignore click
		_player_path.append(node_index)
		_player_cost += edge_cost

	_update_path_display()
	_graph_draw.queue_redraw()


func _get_edge_cost(from: int, to: int) -> int:
	"""Return edge cost or -1 if no edge exists."""
	for neighbor in _adjacency[from]:
		if neighbor["to"] == to:
			return neighbor["cost"]
	return -1


func _update_path_display() -> void:
	if _player_path.is_empty():
		_path_label.text = "Path: (click source node S)"
		_cost_label.text = "Cost: 0"
	else:
		var path_str := ""
		for i in range(_player_path.size()):
			if i > 0:
				path_str += " → "
			path_str += _node_label(_player_path[i])
		_path_label.text = "Path: " + path_str
		_cost_label.text = "Cost: %d" % _player_cost


func _node_label(index: int) -> String:
	if index == _source:
		return "S"
	elif index == _target:
		return "T"
	else:
		return str(index)


func _on_confirm() -> void:
	if is_solved or _player_path.is_empty():
		return
	_attempt_count += 1

	# Must end at target
	if _player_path[-1] != _target:
		_path_label.text = "Route must end at target T!"
		_path_label.add_theme_color_override("font_color", Color("#ff1744"))
		return

	if _player_cost == _optimal_cost:
		_path_label.text = "OPTIMAL ROUTE FOUND!"
		_path_label.add_theme_color_override("font_color", Color("#00e676"))
		_confirm_btn.disabled = true
		complete_module()
	else:
		_path_label.text = "Not optimal (cost %d vs best %d). Try again!" % [_player_cost, _optimal_cost]
		_path_label.add_theme_color_override("font_color", Color("#ff1744"))
		record_wrong_action()
		_on_reset_path()


func _on_reset_path() -> void:
	"""Reset the current path without penalty."""
	_player_path.clear()
	_player_cost = 0
	_update_path_display()
	_path_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	_graph_draw.queue_redraw()


func _on_draw() -> void:
	"""Draw the graph: edges with costs, nodes as circles, player path highlighted."""
	# Draw edges
	for edge in _edges:
		var from_pos: Vector2 = _nodes[edge["from"]]
		var to_pos: Vector2 = _nodes[edge["to"]]
		var color := Color("#555555")

		# Highlight edges in player path
		for i in range(_player_path.size() - 1):
			if (_player_path[i] == edge["from"] and _player_path[i + 1] == edge["to"]) or \
			   (_player_path[i] == edge["to"] and _player_path[i + 1] == edge["from"]):
				color = Color("#00e5ff")
				break

		_graph_draw.draw_line(from_pos, to_pos, color, 2.0)

		# Draw cost label at midpoint
		var mid: Vector2 = (from_pos + to_pos) / 2.0
		var cost_str := str(edge["cost"])
		_graph_draw.draw_string(
			ThemeDB.fallback_font,
			mid + Vector2(-4, -4),
			cost_str,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			14,
			Color("#ffeb3b")
		)

	# Draw nodes
	for i in range(_nodes.size()):
		var pos: Vector2 = _nodes[i]
		var color := Color("#e0e0e0")
		if i == _source:
			color = Color("#00e676")
		elif i == _target:
			color = Color("#ff1744")
		elif i in _player_path:
			color = Color("#00e5ff")

		_graph_draw.draw_circle(pos, NODE_RADIUS, color)
		# Node label
		var label := _node_label(i)
		_graph_draw.draw_string(
			ThemeDB.fallback_font,
			pos + Vector2(-6, 5),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			14,
			Color("#0a0e17")
		)


func get_module_state() -> Dictionary:
	return {
		"module_name": module_name,
		"attempts": _attempt_count,
		"current_cost": _player_cost,
		"optimal_cost": _optimal_cost,
		"path_length": _player_path.size(),
		"mistakes": mistakes,
	}
```

- [ ] **Step 2: Create the .tscn scene file**

Create `game/modules/wire_routing_module.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/wire_routing_module.gd" id="1"]

[node name="WireRoutingModule" type="PanelContainer"]
custom_minimum_size = Vector2(350, 400)
script = ExtResource("1")
```

- [ ] **Step 3: Commit**

```bash
git add game/scripts/wire_routing_module.gd game/modules/wire_routing_module.tscn
git commit -m "feat: add Wire Routing module (Dijkstra shortest path puzzle)"
```

---

## Task 9: Main Menu Scene

**Files:**
- Create: `game/scripts/main_menu.gd`
- Create: `game/scenes/main_menu.tscn`

- [ ] **Step 1: Write main_menu.gd**

Create `game/scripts/main_menu.gd`:

```gdscript
extends Control
## Main menu screen. Start game or quit.

var _title_label: Label
var _subtitle_label: Label
var _start_btn: Button
var _quit_btn: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = Color("#0a0e17")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "BOMB DEFUSAL"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	_title_label.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(_title_label)

	# Subtitle
	_subtitle_label = Label.new()
	_subtitle_label.text = "ALGORITHM MODE"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 24)
	_subtitle_label.add_theme_color_override("font_color", Color("#ff6f00"))
	vbox.add_child(_subtitle_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	# Start button
	_start_btn = Button.new()
	_start_btn.text = "START MISSION"
	_start_btn.custom_minimum_size = Vector2(250, 50)
	_start_btn.add_theme_font_size_override("font_size", 20)
	_start_btn.pressed.connect(_on_start)
	vbox.add_child(_start_btn)

	# Quit button
	_quit_btn = Button.new()
	_quit_btn.text = "QUIT"
	_quit_btn.custom_minimum_size = Vector2(250, 50)
	_quit_btn.add_theme_font_size_override("font_size", 20)
	_quit_btn.pressed.connect(_on_quit)
	vbox.add_child(_quit_btn)

	# Version label
	var version := Label.new()
	version.text = "v0.1.0 — MVP"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_color_override("font_color", Color("#555555"))
	vbox.add_child(version)


func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/bomb_game.tscn")


func _on_quit() -> void:
	get_tree().quit()
```

- [ ] **Step 2: Create the .tscn scene file**

Create `game/scenes/main_menu.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main_menu.gd" id="1"]

[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
```

- [ ] **Step 3: Commit**

```bash
git add game/scripts/main_menu.gd game/scenes/main_menu.tscn
git commit -m "feat: add main menu scene"
```

---

## Task 10: BombGame Scene (Core Game Loop)

**Files:**
- Create: `game/scripts/bomb_game.gd`
- Create: `game/scenes/bomb_game.tscn`

- [ ] **Step 1: Write bomb_game.gd**

Create `game/scripts/bomb_game.gd`:

```gdscript
extends Control
## Main game scene. Manages timer, stability, module instantiation, and win/lose.

const FrequencyLockScene := preload("res://modules/frequency_lock_module.tscn")
const SignalSortingScene := preload("res://modules/signal_sorting_module.tscn")
const WireRoutingScene := preload("res://modules/wire_routing_module.tscn")

# UI references
var _timer_label: Label
var _stability_bar: ProgressBar
var _stability_label: Label
var _mission_label: Label
var _status_label: Label
var _module_container: HBoxContainer

# Pulse animation state
var _pulse_time: float = 0.0


func _ready() -> void:
	_build_ui()
	GameState.reset()
	_instantiate_modules()
	_setup_signals()
	_load_mission_briefing()


func _build_ui() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = Color("#0a0e17")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main layout
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# --- Header row ---
	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	var title := Label.new()
	title.text = "BOMB DEFUSAL SYSTEM"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#00e5ff"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	_timer_label = Label.new()
	_timer_label.text = "02:00"
	_timer_label.add_theme_font_size_override("font_size", 28)
	_timer_label.add_theme_color_override("font_color", Color("#00e5ff"))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(_timer_label)

	# --- Stability bar ---
	var stability_row := HBoxContainer.new()
	stability_row.add_theme_constant_override("separation", 10)
	vbox.add_child(stability_row)

	var stab_title := Label.new()
	stab_title.text = "Stability:"
	stab_title.add_theme_color_override("font_color", Color("#e0e0e0"))
	stability_row.add_child(stab_title)

	_stability_bar = ProgressBar.new()
	_stability_bar.min_value = 0
	_stability_bar.max_value = 100
	_stability_bar.value = 100
	_stability_bar.custom_minimum_size = Vector2(300, 20)
	_stability_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stability_bar.show_percentage = false
	stability_row.add_child(_stability_bar)

	_stability_label = Label.new()
	_stability_label.text = "100%"
	_stability_label.add_theme_color_override("font_color", Color("#00e676"))
	stability_row.add_child(_stability_label)

	# --- Mission text ---
	_mission_label = Label.new()
	_mission_label.text = "Loading mission briefing..."
	_mission_label.add_theme_color_override("font_color", Color("#ff6f00"))
	_mission_label.add_theme_font_size_override("font_size", 14)
	_mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_label.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(_mission_label)

	vbox.add_child(HSeparator.new())

	# --- Module container ---
	_module_container = HBoxContainer.new()
	_module_container.add_theme_constant_override("separation", 15)
	_module_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_module_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_module_container)

	vbox.add_child(HSeparator.new())

	# --- Status bar ---
	_status_label = Label.new()
	_status_label.text = "3 modules remaining"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	_status_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_status_label)


func _instantiate_modules() -> void:
	var modules: Array[PackedScene] = [FrequencyLockScene, SignalSortingScene, WireRoutingScene]
	for scene in modules:
		var module: BaseModule = scene.instantiate()
		module.module_solved.connect(_on_module_solved)
		module.wrong_action.connect(_on_wrong_action)
		_module_container.add_child(module)


func _setup_signals() -> void:
	GameState.stability_changed.connect(_on_stability_changed)
	GameState.game_over.connect(_on_game_over)


func _load_mission_briefing() -> void:
	var fallback := LLMService.get_mission_briefing()
	_mission_label.text = fallback
	# If LLM is active, update when async response arrives
	if not LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.connect(_on_llm_response)


func _on_llm_response(context: String, text: String) -> void:
	if context == "mission_briefing":
		_mission_label.text = text


func _process(delta: float) -> void:
	if not GameState.is_game_active:
		return

	# Tick timer
	GameState.tick_timer(delta)

	# Update timer display
	var t: float = GameState.timer_remaining
	var minutes: int = int(t) / 60
	var seconds: int = int(t) % 60
	_timer_label.text = "%02d:%02d" % [minutes, seconds]

	# Timer color states
	_pulse_time += delta
	if t > 30.0:
		_timer_label.add_theme_color_override("font_color", Color("#00e5ff"))
	elif t > 10.0:
		# Amber pulse
		var alpha: float = 0.7 + 0.3 * sin(_pulse_time * 3.0)
		_timer_label.add_theme_color_override("font_color", Color("#ff6f00", alpha))
	else:
		# Red fast pulse
		var alpha: float = 0.5 + 0.5 * sin(_pulse_time * 8.0)
		_timer_label.add_theme_color_override("font_color", Color("#ff1744", alpha))

	# Update status
	var remaining: int = GameState.modules_total - GameState.modules_solved
	_status_label.text = "%d module(s) remaining" % remaining


func _on_module_solved(module_name: String) -> void:
	# Find the module and get its result
	for child in _module_container.get_children():
		if child is BaseModule and child.module_name == module_name:
			GameState.record_module_solved(child.get_result())
			break


func _on_wrong_action(_module_name: String) -> void:
	GameState.record_wrong_action()


func _on_stability_changed(new_value: int) -> void:
	_stability_bar.value = new_value
	_stability_label.text = "%d%%" % new_value
	if new_value > 60:
		_stability_label.add_theme_color_override("font_color", Color("#00e676"))
	elif new_value > 30:
		_stability_label.add_theme_color_override("font_color", Color("#ff6f00"))
	else:
		_stability_label.add_theme_color_override("font_color", Color("#ff1744"))


func _on_game_over(outcome: String) -> void:
	# Short delay for dramatic effect, then transition
	var timer := get_tree().create_timer(1.5)
	if outcome == "defused":
		_status_label.text = "BOMB DEFUSED! Well done, technician."
		_status_label.add_theme_color_override("font_color", Color("#00e676"))
	elif outcome == "exploded_timer":
		_status_label.text = "TIME'S UP — DETONATION!"
		_status_label.add_theme_color_override("font_color", Color("#ff1744"))
	else:
		_status_label.text = "STABILITY CRITICAL — DETONATION!"
		_status_label.add_theme_color_override("font_color", Color("#ff1744"))
	await timer.timeout
	get_tree().change_scene_to_file("res://scenes/result_screen.tscn")
```

- [ ] **Step 2: Create the .tscn scene file**

Create `game/scenes/bomb_game.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/bomb_game.gd" id="1"]

[node name="BombGame" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
```

- [ ] **Step 3: Commit**

```bash
git add game/scripts/bomb_game.gd game/scenes/bomb_game.tscn
git commit -m "feat: add BombGame scene with timer, stability, and module management"
```

---

## Task 11: Result Screen

**Files:**
- Create: `game/scripts/result_screen.gd`
- Create: `game/scenes/result_screen.tscn`

- [ ] **Step 1: Write result_screen.gd**

Create `game/scripts/result_screen.gd`:

```gdscript
extends Control
## Result screen. Shows win/lose outcome, stats, and algorithm explanations.

var _outcome_label: Label
var _stats_label: Label
var _explanation_label: Label


func _ready() -> void:
	_build_ui()
	_display_results()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color("#0a0e17")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.custom_minimum_size = Vector2(700, 0)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "MISSION DEBRIEF"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Outcome
	_outcome_label = Label.new()
	_outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_outcome_label)

	# Stats
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 16)
	_stats_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	vbox.add_child(_stats_label)

	vbox.add_child(HSeparator.new())

	# Algorithm explanations
	var expl_title := Label.new()
	expl_title.text = "ALGORITHM ANALYSIS"
	expl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expl_title.add_theme_font_size_override("font_size", 20)
	expl_title.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(expl_title)

	_explanation_label = Label.new()
	_explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explanation_label.add_theme_font_size_override("font_size", 14)
	_explanation_label.add_theme_color_override("font_color", Color("#e0e0e0"))
	_explanation_label.custom_minimum_size = Vector2(600, 80)
	vbox.add_child(_explanation_label)

	vbox.add_child(HSeparator.new())

	# Per-module breakdown
	var module_title := Label.new()
	module_title.text = "MODULE BREAKDOWN"
	module_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	module_title.add_theme_font_size_override("font_size", 20)
	module_title.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(module_title)

	for result in GameState.module_results:
		var mod_label := Label.new()
		mod_label.text = "  %s — %d mistake(s) — Algorithm: %s" % [
			result.get("name", "?"),
			result.get("mistakes", 0),
			result.get("algorithm", "?"),
		]
		mod_label.add_theme_color_override("font_color", Color("#e0e0e0"))
		vbox.add_child(mod_label)

	vbox.add_child(HSeparator.new())

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var replay_btn := Button.new()
	replay_btn.text = "REPLAY MISSION"
	replay_btn.custom_minimum_size = Vector2(200, 45)
	replay_btn.add_theme_font_size_override("font_size", 18)
	replay_btn.pressed.connect(_on_replay)
	btn_row.add_child(replay_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(200, 45)
	menu_btn.add_theme_font_size_override("font_size", 18)
	menu_btn.pressed.connect(_on_main_menu)
	btn_row.add_child(menu_btn)


func _display_results() -> void:
	# Outcome
	match GameState.game_outcome:
		"defused":
			_outcome_label.text = "BOMB DEFUSED"
			_outcome_label.add_theme_color_override("font_color", Color("#00e676"))
		"exploded_timer":
			_outcome_label.text = "DETONATION — TIME EXPIRED"
			_outcome_label.add_theme_color_override("font_color", Color("#ff1744"))
		"exploded_stability":
			_outcome_label.text = "DETONATION — STABILITY FAILURE"
			_outcome_label.add_theme_color_override("font_color", Color("#ff1744"))
		_:
			_outcome_label.text = "MISSION STATUS UNKNOWN"
			_outcome_label.add_theme_color_override("font_color", Color("#ff6f00"))

	# Stats
	_stats_label.text = "Time Remaining: %.1fs  |  Mistakes: %d  |  Modules Solved: %d/3" % [
		GameState.timer_remaining,
		GameState.mistakes,
		GameState.modules_solved,
	]

	# LLM summary
	var perf_data := {
		"game_outcome": GameState.game_outcome,
		"timer_remaining": GameState.timer_remaining,
		"total_mistakes": GameState.mistakes,
		"module_results": GameState.module_results,
	}
	_explanation_label.text = LLMService.get_results_summary(perf_data)

	# Listen for async LLM update
	if not LLMService.llm_response_received.is_connected(_on_llm_response):
		LLMService.llm_response_received.connect(_on_llm_response)


func _on_llm_response(context: String, text: String) -> void:
	if context == "results_summary":
		_explanation_label.text = text


func _on_replay() -> void:
	get_tree().change_scene_to_file("res://scenes/bomb_game.tscn")


func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
```

- [ ] **Step 2: Create the .tscn scene file**

Create `game/scenes/result_screen.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/result_screen.gd" id="1"]

[node name="ResultScreen" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
```

- [ ] **Step 3: Commit**

```bash
git add game/scripts/result_screen.gd game/scenes/result_screen.tscn
git commit -m "feat: add result screen with stats, explanations, and LLM summary"
```

---

## Task 12: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write project README**

Replace `README.md` at project root:

```markdown
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
```

- [ ] **Step 2: Create .env.example**

Create `.env.example` at project root:

```
OPENAI_API_KEY=your-key-here
```

- [ ] **Step 3: Commit**

```bash
git add README.md .env.example
git commit -m "docs: add project README and .env.example"
```

---

## Self-Review Checklist

### Spec Coverage
- [x] Project structure (Task 1)
- [x] GameState autoload (Task 3)
- [x] LLMService autoload with OpenAI + fallback (Task 4)
- [x] BaseModule abstract class (Task 5)
- [x] Frequency Lock / binary search (Task 6)
- [x] Signal Sorting / inversions (Task 7)
- [x] Wire Routing / Dijkstra (Task 8)
- [x] Main Menu (Task 9)
- [x] BombGame with timer, stability, modules (Task 10)
- [x] Result Screen with stats + LLM summary (Task 11)
- [x] README + .env (Task 12)
- [x] FastAPI backend with /health, /api/* (Task 2)
- [x] Color palette: all hex values match spec
- [x] Timer states: cyan/amber/red
- [x] Stability bar with color transitions
- [x] Module layout in HBoxContainer
- [x] Offline fallback mode
- [x] LLM async with signals

### Placeholder Scan
- No TBD/TODO found
- All code blocks are complete
- All file paths are exact

### Type Consistency
- `BaseModule` signals: `module_solved(module_name)`, `wrong_action(module_name)` — consistent across all modules and bomb_game.gd
- `GameState` methods: `reset()`, `record_wrong_action()`, `record_module_solved()`, `tick_timer()` — consistent with bomb_game.gd usage
- `LLMService` methods: `get_mission_briefing()`, `get_module_hint()`, `get_results_summary()` — consistent with all callers
- `get_result()` returns `{name, mistakes, algorithm}` — matches result_screen.gd consumption
