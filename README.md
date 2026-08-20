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
driver or the operator. It describes the system, shows and walks through the ML
development lifecycle, advises on adding a new model, and answers questions
about any detail — so that using this toolchain does not require the person who
built it.

**Read [`docs/SCOPE.md`](docs/SCOPE.md) first.** It is the decision record: what
was asked for, which approaches were weighed and rejected, what was settled on
2026-08-20, and what to do next. Its last section says which files to read in
which order.

This is **not** the voice assistant of Layer 5 in `GP/ai/pm_readme.md`. That one
runs on the RPi5 in the IVI and tells the *driver* how much life is left in the
motor. This one runs on the development laptop and tells an *engineer* how the
system works. Confirmed unrelated — they share no code and neither blocks the
other.

## Decisions already taken

| | |
|---|---|
| Command execution | **Read-only** in the first version. `docs/SCOPE.md` §7 explains why, with the bench failure that motivates it |
| Model hosting | **Local** — this laptop, or a second one on the bench acting as a server. No cloud API |
| Text to speech | **No.** That belonged to Layer 5, which this is not |
| First work | **A0: reconcile the documentation corpus.** No AI involved, and the highest-value step |

## Build

Nothing to build yet. No `pdm-app.cmake` marker, so Maestro's configure step
reports `PdM app 'agent': absent -- placeholder tab` and the build is unchanged.
