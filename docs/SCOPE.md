# Scope — what the AI Agent tab is, and why it is that

Written 2026-08-20, at the end of the first scoping conversation. Nothing here
is built yet. This is the decision record: what was asked for, what was ruled
out and why, and what the first steps are.

Read this before writing any code for this repository. If you are a fresh
session picking this up, read [§9](#9-where-to-start-reading) first — it tells
you which files to open in which order.

---

## 1. What this is, and what it is not

**It is an assistant for the developer working on the PdM toolchain.** Someone
sits down in front of Maestro, knows nothing about it, and needs to understand
the system, follow the ML development lifecycle, add their own model, and get
answers about any detail — *without the person who built it sitting next to
them.* That last clause is the whole product requirement, and it is what makes
correctness matter more than fluency here.

**It is not the voice assistant from Layer 5 of `GP/ai/pm_readme.md`.** That one
runs on the RPi5, inside the IVI, and talks to the *driver*: "bearing wear
detected, roughly 200 hours remaining." It answers questions **about the motor**
using numbers the ML models already computed.

This tab runs on the *development laptop* and answers questions **about the
toolchain**. Confirmed 2026-08-20: the two are unrelated, share no code, and
neither blocks the other. Do not let a future reader merge them because both
contain the words "AI" and "assistant" — CLAUDE.md used to warn about exactly
this conflation, and the answer is now settled.

A useful consequence: the Layer 5 assistant *should* be mostly deterministic,
because its answer is a number and an LLM should only phrase it. This tab is the
opposite — retrieving, synthesizing and explaining documentation is a genuine
language task, and it is the one place in this project where a language model is
straightforwardly the right tool.

---

## 2. What was asked for

Five capabilities, deliberately separated because their costs differ by orders
of magnitude:

| # | Capability | What it actually needs | The hard part |
|---|---|---|---|
| **A** | Describe the whole system | Retrieval over the existing docs | Nothing — the corpus already exists and is good |
| **B** | Show the development lifecycle | A navigable *graph*, not prose | Rendering it, and keeping it true as the pipeline moves |
| **C** | Walk a developer through that lifecycle | Knowing **where he currently is** | Reading real state (which artefacts exist, did the gate pass), not just docs |
| **D** | Advise on new models and new data shapes (wide tabular, audio, images) | General ML knowledge | Staying tied to *this system's* constraints instead of drifting into generic advice |
| **E** | Let him issue commands, confirm, and watch the system respond | A command catalogue and a permission model | **Safety — this system can turn a motor** |

A is nearly free. E is the one that can hurt someone. The design effort belongs
at the two ends, not in the middle.

---

## 3. Decisions taken

Three questions were asked and answered on 2026-08-20. These are settled; if you
want to revisit one, say so explicitly rather than quietly designing against a
different answer.

### 3.1 Relationship to Layer 5 — **unrelated**

Settled as described in §1. This tab does not do voice, does not do driver-facing
output, and does not depend on the RPi5.

**Therefore: no TTS.** The text-to-speech question CLAUDE.md left open belonged
to Layer 5, and Layer 5 is not this. Do not add a speech dependency to this repo
without a new conversation.

### 3.2 Command execution — **read-only in the first version**

The agent may inspect and report. It may not change anything. See §7 for the
full reasoning, which is not caution for its own sake — it comes out of a
failure that already happened on this hardware.

### 3.3 Where the model runs — **local, or a local server**

A model on this laptop, or on a second laptop on the bench acting as a server.
Not a cloud API.

The stated constraint alongside it: **keep it simple at the beginning, in small
continuous steps.** That shapes the phase plan in §5 more than any other single
decision — it is why the first two phases contain no model at all.

Design consequence: the model is reached over a URL, so "localhost" and "the
other laptop" are the same code path with a different setting. Put the provider
behind a thin interface from the first line, and make the no-model path a
first-class mode rather than an error state.

---

## 4. The approaches that were weighed

Recorded so the choice can be re-examined, not just inherited.

| Way | What it is | Verdict |
|---|---|---|
| **1. No AI at all** | A guided documentation browser: curated system map, lifecycle diagram, checklists, full-text search, links into real files | **Adopted as the foundation.** Roughly 60% of the value for 15% of the work, cannot hallucinate, and every other approach needs it as substrate anyway |
| **2. RAG** — retrieval-augmented generation | Index the corpus, retrieve relevant chunks per question, answer from them **with citations** | **Adopted as the second layer.** The citation requirement is not decoration — see below |
| **3. LLM with tools** | Give the model `read_file`, `grep`, `get_state`; let it decide what to look at | **Deferred.** Needed eventually for capability C; every tool is a new error surface, so not before the foundation is solid |
| **4. Fine-tuning** | Train a model on the project's documents | **Ruled out.** The corpus is a few hundred KB, it changes every session, and fine-tuning bakes facts into weights **with no citation trail**. It would produce a machine that states stale things confidently. Retrieval does everything it offers, better and cheaper |
| **5. Hybrid** — deterministic skeleton, LLM narration | Graph, state checks and command catalogue are hard-coded; the model routes, explains, and drafts | **This is the architecture.** Ways 1 and 2 are its two floors |

### Why citations are a hard requirement, not a nicety

The stated goal is that the developer *"will not need help from the app creator
or an expert."* That means **nobody is standing by to catch a wrong answer.** A
confident, wrong, uncited explanation becomes something he believes for a week
and builds on.

Every generated answer must cite `file:line` back into the real corpus, and the
citation must be clickable. Then a wrong answer is falsifiable in one click
instead of being indistinguishable from a right one.

### Why the hybrid shape is the right one here specifically

It is the same argument the project's own AI design docs make about the ML
itself: traditional, deterministic methods do the work, and AI makes the result
adaptable and explainable (`GP/ai/pm_readme.md`, "My Recommendation: Hybrid
Approach"). Applying the project's own thesis to the project's own tooling is
both correct and a good thing to be able to say out loud in a defence.

---

## 5. The phase plan

Small steps, in this order. Each phase is useful on its own — none of them is a
half-built thing waiting on the next.

| Phase | What | Model needed? |
|---|---|---|
| **A0** | **Reconcile the documentation corpus** | No |
| **A1** | Deterministic system map + lifecycle view | No |
| **A2** | Grounded Q&A with mandatory citations | Yes |
| **A3** | Stateful walkthrough — "you are here, this is next" | Yes |
| **A4** | Read-only command catalogue | Yes |

**A0 and A1 contain no AI whatsoever, and that is deliberate.** They are also
where most of the value is. A tab that ships at the end of A1 already satisfies
capabilities A and B completely, and cannot be wrong in the way prose can.

### A0 — fix the corpus first

This is the highest-value work in the project and it needs no model at all.

An agent retrieving over contradictory documents does not report the
contradiction. It confidently teaches whichever chunk retrieval happened to
return. **Garbage in, *confident* garbage out** — which is worse than garbage
out, because confidence is precisely what the reader is relying on.

Three live contradictions were found in about twenty minutes of reading on
2026-08-20. There are likely more; finding them is part of A0.

**A0 splits in two, and only one half is ours.** Contradictions 1 and 2 below
are both inside the `AI` repo, which **someone else is actively reworking as of
2026-08-20.** Do not edit that repo, and do not resolve those two from the
outside — the restructure in flight will settle them, and a guess made here
would collide with it. Zee will say when it is finished and worth re-checking.
Until then they are *recorded, not open work.*

What is left in A0 and can proceed: the Maestro-side corpus — this repo's own
docs plus the six app repos' READMEs and `docs/`. Contradiction 3 (`RUN_MIN`)
lives in `esp_dac` and is Zee's call, not a documentation fix.

1. **`AI/README.md` contradicts `AI/host_pipeline/README.md`.** The root README
   says *"nothing under `host_pipeline/`, `rpi_pipeline/` or `MLops/` is
   implemented yet."* `host_pipeline/README.md` says *"All four are
   implemented."* Both are current, in the same repo, one directory apart.

2. **The ML/Ops tab points at a path that moved.** `apps/mlops/MlOpsPage.qml`
   reads `model_out/metrics.json` and runs `python3 -m mlops.gate`. In the `AI`
   repo, `gate.py` now lives at **`old_pipeline/mlops/gate.py`** — the repo was
   restructured into `host_pipeline/`, `rpi_pipeline/` and `MLops/`, and the
   currently checked-out branch is `newPipeline_RUL_v1`, not the `abdelrahman`
   that `docs/ARCHITECTURE.md` names. `docs/STATUS.md`'s account of that tab is
   stale. **Not yet fixed** — establishing which pipeline is authoritative is a
   question for whoever owns the `AI` repo, not something to guess at.

3. **`RUN_MIN` is 100 in the flashed firmware while the README describes 132 as
   settled.** Already documented at length in `docs/STATUS.md`; listed here
   because an agent will read both and must not be left to pick one.

Note the shape of all three: **the prose and the code disagree, and the prose
sounds more confident.** That is the exact failure mode this phase exists to
prevent, and it is why A0 comes before anything that generates sentences.

### A1 — the deterministic views

Two navigable diagrams:

- **The repo graph** — seven repositories, which are submodules, which branch
  each is on, what each contributes. Every node links to that repo's own docs.
- **The ML lifecycle** — `data_building.ipynb` → `anomaly` / `classification` /
  `rul` → `copy_to_rpi.py` → `rpi_pipeline` → gate. Every node links to the
  matching document under `AI/docs/host_pipeline/`, and shows cheap live state
  where it can: does `model/anomaly/` exist, did the gate pass, is the dataset
  still marked `DATA_IS_PROVISIONAL`.

This satisfies "describe the system" and "show the lifecycle" with zero
hallucination risk, and it is the structure A3's walkthrough later narrates.

---

## 6. Capability D — what a good answer looks like

When the developer asks *"what if my data is audio?"* or *"what if I have
hundreds of columns instead of a time series?"*, the valuable answer is **not**
generic ML advice. Any model already knows what a spectrogram is. The valuable
answer is **what breaks in this system**, and that only exists in these
documents:

- `rpi_pipeline/` is hand-written C++ with a vendored kissfft. A 2D CNN over
  scalograms means TensorFlow Lite on the Pi — the exact dependency
  `pdm_mlops_gui` was **deliberately architected to avoid** (see
  `docs/ARCHITECTURE.md`, "ML/Ops: a new GUI, not the AI repo as a submodule").
  So the honest answer names a deployment problem, not a modelling one.
- The adaptability story rests on ~20–30 z-score-normalized physics features
  (`GP/ai/2_pm_HypridAdabtiveDesign2.md` §10, "Making It Work On Any Motor").
  Wide tabular input does not merely add columns — it **breaks the mechanism
  that lets one trained model work on a different motor without retraining.**

That class of answer is the product. It is only possible because the agent is
grounded in this corpus rather than in the internet, which is the second reason
A0 matters.

---

## 7. Why commands are read-only, with the evidence

The ask was: the developer writes what he needs, confirms it, and watches the
real system respond. That is reasonable and it is the eventual target. What is
ruled out is **a text generator with a path to the serial port**, and the reason
is not general caution — it is a failure that already occurred on this bench.

From `esp_dac/docs/06-safety.md`, quoted in `apps/motor_control/README.md`:

> A single keystroke starts the motor. `a`–`j`, `s` and `z` run with no
> confirmation. Any code path that can put a stray byte on the port can start a
> three-minute run.

And from `docs/STATUS.md`, bug 8's history: a failed upload once left **10,784
bytes in flight, which the board read as keystrokes** — and `e` and `d` are
scenario letters. **The motor ran.** The only symptom was a board that appeared
to have gone quiet.

A language model emitting free text toward that port is that same failure mode
with a probability distribution attached. So when capability E is eventually
built:

- **A fixed, enumerated command catalogue.** The model's only power is to
  *select one entry and fill its typed parameters.* It cannot invent an action
  and it cannot emit raw bytes.
- **Every proposal renders as a card a human clicks** — stating what it does,
  what it touches, and whether the motor turns.
- **Read-only actions run immediately**: describe state, list recordings, read
  the gate report, tail the board log. This is most of what is actually useful,
  and it is all of version one.
- **Motor-turning actions are excluded**, and there is a design reason beyond
  safety: the scenario grid is already right there, already has a confirmation
  dialog, and is already the better UI for starting a run. The agent adds risk
  and no capability.
- **OTA is excluded** for the same reason, more so — it can kill hypervisor
  guests and push updates over MQTT.

---

## 8. Open questions

Not blocking A0 or A1. Worth settling before A2.

1. **Which local model, and running where.** "Local, or a second laptop as a
   server" is decided; the specific runtime is not. Whatever it is, reach it
   over a URL so both cases are one code path.
2. **What exactly is in the corpus.** All markdown in all seven repos is the
   obvious start. Source files are a judgement call — they are the ground truth
   when prose disagrees, but they are also most of the tokens.
3. **How the tab reads state from other tabs.** The integration contract says
   `MessageBus`, never a direct dependency on another app repo
   (`docs/INTEGRATION_CONTRACT.md`). Some state the agent wants may not be
   published yet.
4. **Who the developer is.** A teammate joining next month, or a hypothetical
   user for the defence demo? It changes how much the agent should assume.
5. **`shell/main.cpp` still says `pdm_agent_gui (to be created)`.** The repo is
   `pdm_ai_agent_gui` and it exists. One string, left alone deliberately so the
   submodule commit stayed pure.

---

## 9. Where to start reading

In this order. Do not skip the first two; everything else assumes them.

| # | File | Why |
|---|---|---|
| 1 | `PdM-Maestro_gui/CLAUDE.md` | The map for the whole project — repo layout, branch policy, build, per-tab state |
| 2 | `PdM-Maestro_gui/docs/STATUS.md` | The detailed log: every bug with its root cause, and which claims are bench-verified versus only unit-tested |
| 3 | **This file** | What this tab is, what was decided, what is deliberately not being built |
| 4 | `PdM-Maestro_gui/docs/INTEGRATION_CONTRACT.md` | The eleven rules this repo must satisfy to become a tab. Read before the first line of code |
| 5 | `AI/docs/README.md` and `AI/host_pipeline/README.md` | The ML lifecycle the agent has to explain — read them noting the contradiction in §5 |
| 6 | `GP/ai/pm_readme.md` | The original design. Read it to understand Layer 5 **and to confirm this tab is not it** |

### For the next session, concretely

The next piece of work is **A0**, and it is documentation reconciliation, not
programming.

**The `AI` repo half of it is not available.** Someone else is reworking that
repo as of 2026-08-20; contradictions 1 and 2 in §5 will be settled by that
work, not by us. Do not edit it, do not resolve them from outside, and do not
treat them as blocking. Zee will say when it is done and worth re-checking —
at which point the questions to answer are: which pipeline is authoritative,
and what should the ML/Ops tab be pointing at.

**What can proceed now** is the Maestro-side corpus: this repo, the shell's
own `docs/`, and the six app repos' READMEs and `docs/`. Read them against the
code rather than against each other — every contradiction found so far had the
same shape, prose more confident than the source it describes.

Do not start A2 before the reachable part of A0 is done. An assistant built on
a corpus that contradicts itself will teach the contradictions with a straight
face, and the person it is teaching has, by design, nobody to check it against.
