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

**A2a done:** a Python server outside Qt (`server/`), reached over HTTP —
health, model listing and download, and a first grounded `/chat` that pasted
the whole reachable corpus into the system prompt.

**A2b done, both halves, and run against real hardware.** Retrieval: the
server chunks the corpus at markdown headings, embeds the chunks, and
retrieves only the top few sections per question — the whole-corpus prompt
above didn't fit the hardware floor this project targets, see
`server/README.md` for the measured numbers. Tool-calling: `search_docs`,
`read_file`, `list_repo`, `navigate_to`, model-driven with a deterministic
fallback (`docs/SCOPE.md` §6.3). `navigate_to` can also name one UI element
to flash after the switch — a real guided-tour case, not just a tab jump —
see "Using the AI Agent" below and `server/tools.py`'s `HIGHLIGHT_TARGETS`.

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

## Using the AI Agent

Open the **AI Agent** tab (the star icon, rightmost in the bar). The status
pill top-right shows whether it's actually reachable — a red dot means the
Python server or the model backend isn't up; see `server/README.md` if it
stays that way.

**Asking a question.** Type into the box and press Enter or **Ask**. Before
your first question, the box shows example questions grouped by category
(System, Motor Rig, ML / Data) — click one to fill the box with it rather
than typing it out. Every answer cites the document section it came from as
a numbered chip below it; hover a chip to see the file and a similarity
score. A chip's color says something real:

| Chip | Meaning |
|---|---|
| filled blue, bracket lit | cited, and the answer actually matches this section |
| filled red | cited, but the answer doesn't match what it claims to — treat the answer as unverified |
| pale, unlit | retrieved for the question but the answer never used it |

If every chip is unlit, the header above them says so plainly ("cited none
of them") — that's the agent being honest that it couldn't ground the
answer, not a rendering bug.

**Follow-up questions.** The conversation keeps going — every question and
answer stays on screen, and each new question is asked with the earlier ones
as context, so "and what if that fails partway through" means what it looks
like it means. There's no way to clear the transcript short of leaving the
tab and coming back (switching tabs doesn't destroy it either, by design —
see `docs/ARCHITECTURE.md`'s "Tabs are kept alive").

**"Take me there."** When an answer explains something that lives on a
specific tab, a suggestion appears a couple of seconds after the answer
finishes — *"Want me to take you to the Motor Control tab?"* — with **Take
me there** and **Not now** buttons. Nothing switches tabs on its own; you
click to confirm. This is deliberate, not a missing feature: an earlier
version switched the instant the model decided to, before a word of the
explanation had rendered, and it read as the tab being yanked out from under
the sentence explaining it.

**Guided highlights.** Some suggestions also flash a specific control once
you land on the tab — Motor Control's fetch panel is the one wired up so
far, so ask something like *"how do I fetch recordings off the rig"* to see
it: a blue ring pulses around the panel a few times. This is new and grows
one element at a time (`server/tools.py`'s `HIGHLIGHT_TARGETS`); most tabs
don't have anything wired to flash yet.

**A note on reliability.** The model picks which tool to call, and it isn't
always right — asked the same question twice, it might navigate correctly
once and just answer in prose the next time, or it might occasionally name
the wrong tab (which the server catches and reports back as an error rather
than navigating somewhere wrong). This is expected at this model size, not a
bug to report; a bigger/better local model will do this more reliably at
the cost of more VRAM and a slower answer. The **grounded, cited answer is
always there regardless** — navigation and highlighting are additive on top
of it, never required for the answer to be correct.

## Decisions already taken

| | |
|---|---|
| "Act" commands (run a scenario, fetch, OTA) | **Still read-only.** `docs/SCOPE.md` §8 explains why, with the bench failure that motivates it |
| Read and navigate tools (list recordings, switch tabs) | **In scope for A2b.** Can't affect the system — `docs/SCOPE.md` §6.2 |
| The AI itself | **Outside Qt**, a local Python server reached over HTTP — `docs/SCOPE.md` §6.1 |
| Model hosting | **Local**, via `llama.cpp` or Ollama — this laptop or a second one as a server, backend/model/host all configuration. `llama.cpp` is the default; see `server/README.md` for why it needs a second `llama-server` process once embeddings are involved. A GTX 1650 (`qwen2.5:1.5b`-class, `n_ctx` 2048–4096) is the design floor, not this laptop. `docs/SCOPE.md` §6.4 |
| Tool-calling | **Model-driven, deterministic retrieval underneath as the real fallback** for weak models or failed calls — built, `docs/SCOPE.md` §6.3 |
| Retrieval | **Semantic search (embeddings), no vector database needed at this corpus size** — implemented; see `server/README.md`'s "Retrieval" section for the chunk counts and prompt-size measurements. `docs/SCOPE.md` §6.5 |
| Text to speech | **No.** That belonged to Layer 5, which this is not |

## Build

```bash
cmake -B build -DCMAKE_PREFIX_PATH=$HOME/Qt/6.10.3/gcc_64
cmake --build build -j$(nproc)
./build/agent_gui
```

Qt 6.5+, CMake 3.21+. Same shape as `pdm_mlops_gui` — see its README for the
reasoning behind the standalone/library split.
