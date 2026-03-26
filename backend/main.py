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


class MissionBriefingRequest(BaseModel):
    city: str = ""
    wave: int = 1
    threat_level: str = "LOW"


class ResultsSummaryRequest(BaseModel):
    game_outcome: str
    timer_remaining: float
    total_mistakes: int
    module_results: list[dict[str, Any]]
    waves_survived: int = 0
    city_name: str = ""


# --- Endpoints ---


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/api/mission-briefing")
def mission_briefing(req: MissionBriefingRequest = MissionBriefingRequest()):
    system = (
        "You are a CIA mission briefing narrator for a bomb defusal game. "
        "The player is Agent CIPHER, a counter-algorithm terrorism operative. "
        "A terrorist organization called NEXUS has planted algorithm-locked bombs worldwide. "
        "Write a 2-3 sentence tense, immersive briefing specific to the given city. "
        "Reference the city's characteristics. Keep it short and punchy."
    )
    if req.city:
        user = (
            f"Generate a mission briefing for wave {req.wave} in {req.city}. "
            f"Threat level: {req.threat_level}. "
            f"The agent is deploying to defuse a NEXUS device."
        )
    else:
        user = (
            "Generate the opening briefing for Operation Darkfire. "
            "NEXUS has planted 10 algorithm-locked bombs in cities worldwide. "
            "Agent CIPHER is being activated."
        )
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


class CommentaryRequest(BaseModel):
    event: str  # "wrong_action", "module_solved", "time_warning", "stability_warning"
    module_name: str = ""
    details: dict[str, Any] = {}
    city: str = ""
    wave: int = 1


@app.post("/api/commentary")
def commentary(req: CommentaryRequest):
    system = (
        "You are an AI handler guiding Agent CIPHER during a bomb defusal mission. "
        "Give a SHORT (1 sentence max, under 15 words) real-time reaction to what just happened. "
        "Be dramatic, urgent, and in-character. Mix encouragement with tension. "
        "Reference the specific event. Never break character."
    )
    event_descriptions = {
        "wrong_action": f"Agent made a mistake on the {req.module_name} module in {req.city}. Details: {req.details}",
        "module_solved": f"Agent just solved the {req.module_name} module in {req.city}! Details: {req.details}",
        "time_warning": f"Timer is running low in {req.city}! Only {req.details.get('seconds_left', '?')}s remaining.",
        "stability_warning": f"Bomb stability critical in {req.city}! Stability at {req.details.get('stability', '?')}%.",
        "half_time": f"Half the time is gone in {req.city}. {req.details.get('modules_remaining', '?')} modules remaining.",
    }
    user = event_descriptions.get(req.event, f"Event: {req.event} in {req.city}")
    text = _chat(system, user)
    return {"text": text}


@app.post("/api/results-summary")
def results_summary(req: ResultsSummaryRequest):
    system = (
        "You are an educational debrief AI for a CIA bomb defusal game that teaches algorithms. "
        "The player is Agent CIPHER fighting NEXUS across world cities. "
        "Summarize the player's performance, mention how many waves/cities they survived, "
        "and explain the algorithm behind each module. "
        "Be encouraging, educational, and concise. Use 3-5 sentences total."
    )
    modules_str = "\n".join(
        f"- {m.get('name', '?')}: {m.get('mistakes', 0)} mistakes, "
        f"algorithm: {m.get('algorithm', '?')}"
        for m in req.module_results
    )
    user = (
        f"Game outcome: {req.game_outcome}\n"
        f"Waves survived: {req.waves_survived}/10\n"
        f"Last city: {req.city_name}\n"
        f"Time remaining: {req.timer_remaining:.1f}s\n"
        f"Total mistakes: {req.total_mistakes}\n"
        f"Modules:\n{modules_str}\n\n"
        f"Give a short educational debrief."
    )
    text = _chat(system, user)
    return {"text": text}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info", access_log=True)
