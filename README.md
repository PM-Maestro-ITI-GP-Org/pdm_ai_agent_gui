# pdm_ai_agent_gui

The AI Agent tab of [PdM Maestro](https://github.com/PM-Maestro-ITI-GP-Org/PdM-Maestro_gui),
and a standalone app in its own right.

## State

**Scaffolding only. No code yet, and the scope is still being settled.**

This repository exists so the tab has a home and the submodule slot is real.
It carries no `pdm-app.cmake` marker yet, so Maestro's build skips it and the
tab keeps its placeholder — see the app-discovery block in Maestro's top-level
`CMakeLists.txt`.

## What it is meant to be

An assistant for the **developer** working on the PdM toolchain, not for the
driver or the operator. Read [`docs/SCOPE.md`](docs/SCOPE.md) first — it is the
record of what was asked for, the options weighed, and what was decided.

Note that this is a different thing from the "voice assistant" of Layer 5 in
`GP/ai/pm_readme.md`. That one answers *"how much life is left in the motor?"*
for an end user. This one answers *"how do I add my own model to this system?"*
for an engineer. Do not conflate them; see `docs/SCOPE.md`.

## Build

Nothing to build yet.
