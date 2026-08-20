# pdm_ai_agent_gui

The AI Agent tab of [PdM Maestro](https://github.com/PM-Maestro-ITI-GP-Org/PdM-Maestro_gui),
and a standalone app in its own right.

## State

**A1 done: a real tab, two deterministic views, no AI yet.** Integrated
against the contract — library + `PdM.Agent` QML module, builds inside
Maestro and standalone. `pdm-app.cmake` is present, so Maestro's configure
step reports `agent: integrated as pdm_agent (PdM.Agent)`, not a placeholder.

- **System Map** — the eight repos in this toolchain, each linking to its own
  docs.
- **Lifecycle view** — the ML pipeline stages, with a visible banner marking
  the AI-repo-sourced parts provisional while that repo is being reworked.

**Next: A2a**, a Python server outside Qt that the tab talks to over HTTP —
see `docs/SCOPE.md` §6 and its last section for exactly what that means.

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
| "Act" commands (run a scenario, fetch, OTA) | **Still read-only.** `docs/SCOPE.md` §8 explains why, with the bench failure that motivates it |
| Read and navigate tools (list recordings, switch tabs) | **In scope for A2b.** Can't affect the system — `docs/SCOPE.md` §6.2 |
| The AI itself | **Outside Qt**, a local Python server reached over HTTP — `docs/SCOPE.md` §6.1 |
| Model hosting | **Local via Ollama** — this laptop or a second one as a server, model name and host both configuration. `qwen2.5:3b` here today; a GTX 1650 (`qwen2.5:1.5b`-class) is the design floor, not this laptop. `docs/SCOPE.md` §6.4 |
| Tool-calling | **Model-driven, with a deterministic pattern-matching fallback** for weak models or failed calls — `docs/SCOPE.md` §6.3 |
| Retrieval | **Semantic search (embeddings)**, no vector database needed at this corpus size — `docs/SCOPE.md` §6.5 |
| Text to speech | **No.** That belonged to Layer 5, which this is not |

## Build

```bash
cmake -B build -DCMAKE_PREFIX_PATH=$HOME/Qt/6.10.3/gcc_64
cmake --build build -j$(nproc)
./build/agent_gui
```

Qt 6.5+, CMake 3.21+. Same shape as `pdm_mlops_gui` — see its README for the
reasoning behind the standalone/library split.
