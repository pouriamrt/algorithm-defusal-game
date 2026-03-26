# Bomb Defusal: Wave System, Adaptive Difficulty & Visual Overhaul — Design Spec

## Overview

Enhance the Bomb Defusal game with a CIA operative narrative, world map progression across 10 cities, adaptive difficulty that responds to player performance, larger/more visible LLM text with typewriter briefings, and city-themed visual enhancements.

## 1. Story & Narrative

### Premise
Player is **Agent CIPHER**, CIA Counter-Algorithm Terrorism Unit (CATU). Organization **NEXUS** has planted algorithm-locked bombs in 10 cities. Player deploys to each city in sequence, defusing increasingly complex devices.

### Opening Sequence
- Dark classified-document styled overlay before Wave 1
- CIA seal watermark, "CLASSIFIED — EYES ONLY" header
- LLM-generated (or fallback) mission briefing explaining the global threat
- "ACCEPT MISSION" button

### 10 Cities (Waves)

| Wave | City | Region | Accent Color | Threat Level |
|------|------|--------|-------------|-------------|
| 1 | Washington D.C. | North America | `#4488ff` (blue) | LOW |
| 2 | London | Europe | `#7799bb` (gray-blue) | LOW |
| 3 | Paris | Europe | `#ddaa44` (gold) | MODERATE |
| 4 | Tokyo | Asia | `#ff44aa` (neon pink) | MODERATE |
| 5 | Cairo | Africa | `#ddaa55` (sand amber) | ELEVATED |
| 6 | Moscow | Europe | `#aaccee` (ice white) | ELEVATED |
| 7 | Mumbai | Asia | `#ff8833` (saffron) | HIGH |
| 8 | Sydney | Oceania | `#33bbaa` (ocean teal) | HIGH |
| 9 | Rio de Janeiro | South America | `#44dd66` (green-gold) | SEVERE |
| 10 | Pyongyang | Asia | `#dd2222` (red) | CRITICAL |

Each city has approximate lat/lon for map placement.

## 2. Game Flow (Revised)

```
MainMenu → OpeningBriefing → WorldMap (Wave 1) → BombGame → WaveComplete
    ↑                                                           ↓
    ← ← ← ← ← ResultScreen (game over) ← ← ← ← ← ← WorldMap (Wave N+1)
                                                         ↓
                                                    BombGame → ...
```

### Scene Transitions
1. **MainMenu**: Title + "START MISSION" + "QUIT"
2. **OpeningBriefing**: Classified document overlay, LLM narrative, "ACCEPT MISSION"
3. **WorldMap**: Animated world map, flight path, city info, LLM intel briefing with typewriter effect, "DEPLOY" button
4. **BombGame**: Existing game scene with adaptive params, enhanced visuals
5. **WaveComplete**: Brief "BOMB DEFUSED" overlay (1.5s) → auto-transition to WorldMap for next wave
6. **ResultScreen**: Shown on game over (timer/stability=0). Shows waves survived, total stats, LLM debrief, per-module algorithm cards, "REPLAY" / "MAIN MENU"

### New Scenes/Scripts Needed
- `opening_briefing.gd` + `opening_briefing.tscn` — classified document intro
- `world_map.gd` + `world_map.tscn` — map screen between waves
- `difficulty_manager.gd` — autoload singleton for adaptive difficulty
- `wave_data.gd` — static data for city definitions

## 3. Adaptive Difficulty Engine

### DifficultyManager Autoload

Tracks:
- `current_wave: int` (1–10)
- `wave_history: Array[Dictionary]` — per-wave performance: `{time_used, mistakes, efficiency}`
- `last_efficiency: float` — performance score from previous wave

### Efficiency Score (per wave)
```
efficiency = (1 - time_used/timer_total) * 0.5 + (1 - mistakes/max_allowed_mistakes) * 0.5
```
Clamped to 0.0–1.0. `max_allowed_mistakes` = 10 (stability/penalty).

### Difficulty Parameters

`get_wave_params(wave: int) -> Dictionary` returns:

| Parameter | Formula | Wave 1 | Wave 5 | Wave 10 |
|-----------|---------|--------|--------|---------|
| timer | `max(60, 150 - (wave-1)*10 - adaptive_bonus)` | 150s | 110s | 60s |
| stability | `max(50, 100 - (wave-1)*5)` | 100 | 80 | 55 |
| stability_penalty | `int(10 + (wave-1)*1.5)` | 10 | 16 | 23 |
| freq_range_max | `int(50 * pow(1.4, wave-1))` capped at 1000 | 50 | 192 | 1000 |
| sort_elements | `min(10, 5 + int((wave-1)*0.5))` | 5 | 7 | 9 |
| graph_nodes | `min(9, 5 + int((wave-1)*0.4))` | 5 | 6 | 8 |
| graph_extra_edges | `min(6, 2 + int((wave-1)*0.4))` | 2 | 3 | 5 |

### Adaptive Bonus
- If `last_efficiency > 0.7`: timer gets extra -10s, sort gets +1 element, graph gets +1 node
- If `last_efficiency < 0.3`: parameters stay same as previous wave (mercy round)
- Wave 1 always uses base params (no previous efficiency exists)

### GameState Changes
- `GameState.reset()` now accepts a `params: Dictionary` from DifficultyManager
- Modules read params from GameState on `reset_module()`

## 4. LLM Text Visibility

### A. Mission Briefing Overlay (new scene: OpeningBriefing + reused in WorldMap)
- Full-screen semi-transparent dark overlay (`Color(0, 0, 0, 0.85)`)
- Centered panel (700×400px) with classified document styling
- CIA seal as drawn watermark (circle + text)
- Header: city name + threat level in accent color
- Body: LLM text at **20px font**, typewriter animation (chars appear over ~3 seconds)
- Button: "DEPLOY" / "ACCEPT MISSION" at bottom

### B. In-Game Intel Bar (replaces small mission label in BombGame)
- Dedicated panel with amber border at top of game screen
- **16px font**, full width, 2-3 lines visible
- Hint text appears here when requested — highlighted with pulsing border for 3s
- LLM async update replaces text smoothly

### C. Results Debrief Cards (enhanced ResultScreen)
- LLM summary at **18px font** in styled panel
- Per-module "cards": colored header bar + module name + mistakes count + algorithm explanation paragraph
- Total stats: waves survived, total time, total mistakes
- If all 10 waves completed: special "WORLD SAVED" victory screen

### Backend Changes
- `/api/mission-briefing` now accepts `{city, wave, threat_level}` for city-specific briefings
- `/api/module-hint` unchanged
- `/api/results-summary` now accepts `{waves_survived, ...}` for wave-aware summaries

## 5. World Map Screen

### Map Drawing (`world_map.gd`)
- Dark background with simplified continent outlines drawn as polygon lines (glow effect)
- 10 city dots positioned at approximate coordinates
- Completed cities: green dot + small checkmark
- Current target: red pulsing dot with expanding ring
- Upcoming: dim gray dots
- Flight path: animated dashed line from last completed city to current target

### City Info Panel (right side)
- City name in large accent-colored text (24px)
- Region + threat level
- Wave number: "WAVE 3 OF 10"
- LLM intel briefing with typewriter effect (20px)
- Difficulty preview: timer, stability shown as small bars
- "DEPLOY" button (accent colored)

### Flight Animation
- When map loads, a dotted line animates from previous city to current city over 1.5s
- Camera (view) can be static — the animation is just the line drawing itself

## 6. Visual Enhancements

### City-Themed Accents
- `TechBackground.set_accent_color(color)` — grid lines, particles, HUD corners tint to city color
- `BombVisual` wire veins tint to city accent
- Module panel borders get subtle glow in accent color

### Module Panel Styling
- Each module panel gets a 1px glowing border in city accent
- Solved: border turns green with fade-pulse
- Unsolved: dim accent border

### Bomb Evolution
- Wire vein count increases with wave number (more veins = visually busier)
- LED blink rate increases with wave
- Bomb gains additional rivet rings at higher waves

### Wave Transition
1. "BOMB DEFUSED" + green flash (existing)
2. 0.5s fade to black
3. World map appears with flight path animation
4. City info panel + typewriter briefing
5. Player clicks "DEPLOY"
6. 0.3s fade to black → BombGame loads with new params

### City Name Watermark
- Large faded text (60px, alpha 0.04) of the city name drawn in TechBackground behind everything

## 7. File Changes Summary

### New Files
| File | Purpose |
|------|---------|
| `game/autoload/difficulty_manager.gd` | Adaptive difficulty singleton |
| `game/autoload/wave_data.gd` | Static city definitions (name, coords, accent, threat) |
| `game/scripts/opening_briefing.gd` | Opening classified document scene |
| `game/scenes/opening_briefing.tscn` | Opening scene |
| `game/scripts/world_map.gd` | World map between waves |
| `game/scenes/world_map.tscn` | Map scene |
| `game/scripts/briefing_overlay.gd` | Reusable typewriter briefing panel |

### Modified Files
| File | Changes |
|------|---------|
| `game/autoload/game_state.gd` | Accept params dict in reset(), store current_wave |
| `game/autoload/llm_service.gd` | City-aware briefing requests, wave-aware summaries |
| `game/scripts/bomb_game.gd` | Read difficulty params, pass accent color, wave transition |
| `game/scripts/base_module.gd` | Read difficulty params from GameState |
| `game/scripts/frequency_lock_module.gd` | Configurable range from params |
| `game/scripts/signal_sorting_module.gd` | Configurable element count from params |
| `game/scripts/wire_routing_module.gd` | Configurable node/edge count from params |
| `game/scripts/result_screen.gd` | Wave stats, debrief cards, waves_survived |
| `game/scripts/tech_background.gd` | City accent color, watermark text |
| `game/scripts/bomb_visual.gd` | Accent-colored veins, wave-based complexity |
| `game/scripts/main_menu.gd` | Navigate to opening_briefing instead of bomb_game |
| `game/project.godot` | Register DifficultyManager autoload |
| `backend/main.py` | City-aware briefing endpoint |

## 8. Scope Boundaries

**In scope:** All of the above.

**Out of scope for this enhancement:**
- Sound effects / music (future enhancement)
- Save/load progress between sessions
- Online leaderboards
- Additional module types beyond the original 3
- Localization / multiple languages
