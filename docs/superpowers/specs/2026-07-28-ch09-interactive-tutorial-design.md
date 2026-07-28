# Ch09 Interactive Tutorial

Date: 2026-07-28

## Goal

Add a first-run interactive tutorial before the Ch09 12-node run. The tutorial
must teach the player by requiring real gameplay actions, then start a clean
formal run with no tutorial state leaking into the deck, stability, budget,
route, score, or runtime report.

The tutorial teaches:

1. The purpose and order of the 12-node run.
2. Fault intent and end-of-turn actions.
3. Processing points and card costs.
4. Defense and stability loss.
5. The engineering chain from raw data to trusted data to output.
6. Repair progress, weakness tags, and evidence gates.

## Product Decisions

- The tutorial appears automatically only when no completed tutorial record
  exists for the current tutorial version.
- It is an isolated scripted practice encounter, not the formal first node.
- It uses strong guidance: only the control required by the current step is
  actionable.
- A visible `Skip tutorial` command remains available throughout.
- Skipping marks the current tutorial version complete and starts the formal
  run.
- Completing or skipping the tutorial does not report a completed gameplay
  attempt.
- Node Lab bypasses the tutorial.
- A forced tutorial launch is available for development and QA through
  `--tutorial` and the Web query `?tutorial=1`.

## Tutorial Flow

### 1. Training Briefing

The normal run HUD remains visible while the scene stage shows a compact
training briefing.

The briefing introduces the formal structure:

- 12 nodes in a single route.
- Faults and checkpoints test engineering evidence.
- Rewards, events, components, shops, and service nodes shape the deck.
- Node 11 is mandatory pre-Boss service.
- Node 12 is a three-phase system acceptance Boss.

The route explanation is short and visual. The only primary action is
`Enter training fault`.

### 2. Read Fault Intent

The tutorial opens a dedicated training fault in the normal encounter layout.
The intent area is highlighted and the player must activate it before any card
can be played.

The coach text explains that the fault acts after the player ends the turn and
that intent should be read before spending processing points.

### 3. Build Defense

The first scripted hand contains `sliding_average`. Other controls remain
disabled.

Playing the card demonstrates:

- Card cost.
- Processing-point reduction.
- Defense gain.
- Immediate card feedback.

### 4. End The Turn

The end-turn command becomes active. The training fault performs a six-point
stability attack, which is absorbed by the defense created in the previous
step.

The tutorial then refreshes processing points and replaces the hand with the
fixed engineering chain for turn two.

### 5. Complete The Engineering Chain

The second turn unlocks one card at a time in this order:

1. `mq2_sample`: creates smoke raw data.
2. `adc_convert`: converts smoke raw data into trusted data.
3. `led_alarm`: consumes trusted smoke data and performs the output response.

Each successful action advances the tutorial and highlights the value that
changed. The encounter uses the same card rule implementation as the formal
run. The training repair target and evidence gate are deterministic so the
third card completes the fault.

### 6. Start The Formal Run

The completion layer summarizes the loop:

`read intent -> spend points -> build evidence -> repair fault -> improve deck`

It also states that formal combat rewards add cards and that utility nodes alter
the rest of the run. Activating `Start formal run` destroys the tutorial
fixture, creates the normal starter deck, restores full stability and starting
budget, seeds the selected 12-node map, begins the runtime attempt, and shows
node 1.

## Guidance Behavior

The tutorial is driven by an explicit step enum rather than inferred from
labels or animation timing.

At every step:

- The required target receives a teal focus frame and a short instruction.
- Irrelevant card buttons and commands are disabled.
- Clicking outside the target does not advance the tutorial.
- An invalid action produces a single short hint in the coach strip.
- Completion depends on the real gameplay method returning success.
- Animations are optional; step completion never depends on animation events.

The coach strip stays above the footer and never covers the intent, repair
bridge, hand, or end-turn command. On mobile it occupies a compact band between
the HUD and the active encounter region.

## Persistence

Tutorial completion uses a versioned record in:

`user://ch09_tutorial.cfg`

The record contains:

- `version`: integer tutorial content version.
- `completed`: boolean.

The first-run decision is:

1. Node Lab requested: enter Node Lab.
2. Forced tutorial requested: enter the tutorial regardless of the record.
3. Completion record matches the current version: start the formal run.
4. Otherwise: enter the tutorial.

Incrementing the version intentionally shows a materially revised tutorial once
to returning players. A persistence write failure must not block the formal
run; it logs a warning and continues.

## Runtime Isolation

The runtime attempt begins only when the formal run is initialized.

The tutorial must not call:

- `runtime.begin_attempt()`
- `runtime.complete()`
- Normal node visit reporting
- Score calculation

Tutorial actions use existing card-effect functions but operate on a dedicated
fixed fixture. Formal run initialization replaces every mutable tutorial value,
including deck piles, hand, powers, data counters, evidence, intent index,
repair progress, stability, budget, visited nodes, reports, and timing.

Runtime reset during the formal run resets the formal run and does not replay a
completed tutorial.

## Architecture

The implementation preserves the Ch11/Ch12-aligned project structure:

- Thin `main.tscn`
- One root gameplay controller
- Local JSON content
- Shared `dgbook_runtime`
- SceneTree tests

The root controller gains focused tutorial helpers:

- First-run and forced-launch decision.
- Tutorial fixture initialization.
- Step gating and advancement.
- Tutorial completion persistence.
- Clean transition into `_reset_run()`.

The tutorial UI is built as another focused scene-stage view plus a lightweight
coach overlay. It does not create a second gameplay state machine or duplicate
card-effect rules.

The training encounter definition is local tutorial fixture data. Its cards
reference existing card IDs, ensuring the taught actions match formal gameplay.

## Responsive Layout

### Desktop: 1280 x 720

- Briefing uses the same centered vertical-route language as the formal map.
- Encounter composition remains device, evidence, and fault from left to right.
- Coach guidance fits above the action dock.
- Highlight frames do not alter control size or shift the layout.

### Mobile: 390 x 844

- Briefing becomes a single scrollable column.
- Encounter retains the fault, evidence, device, then hand order.
- The coach strip uses at most two short lines plus the skip icon.
- The required card is scrolled fully into view before it becomes actionable.
- End turn remains above the footer with a minimum 44-pixel touch target.

## Skip And Recovery

- `Skip tutorial` is available from every tutorial step.
- Skipping writes completion, clears tutorial state, and starts a fresh formal
  run.
- If required tutorial fixture data is missing, the game logs the missing ID,
  marks no gameplay result, and starts the formal run.
- If the UI is resized mid-step, the same step and target remain active.
- Reloading before completion shows the tutorial again because completion is
  written only after completion or an explicit skip.

## Test Strategy

### Automated

Add a dedicated SceneTree tutorial test that verifies:

1. A missing completion record selects the tutorial.
2. A matching completion record selects the formal run.
3. Node Lab bypasses the tutorial.
4. Forced launch overrides completion.
5. Only the required control is actionable at each step.
6. The exact scripted card order advances the tutorial.
7. Wrong card IDs and premature end-turn actions are rejected.
8. Defense absorbs the scripted fault attack.
9. Raw smoke becomes trusted smoke before the output card is accepted.
10. Completing and skipping both start a clean formal run.
11. Tutorial actions do not call runtime attempt completion or alter run stats.

Extend gray-box UI coverage at both reference viewports:

- Briefing and primary command are visible.
- Coach strip does not overlap the target or footer.
- Required card is fully visible.
- Skip remains reachable.
- Live resize preserves the current step.

Preserve all existing data, card, run-flow, random, runtime, Node Lab, full-run,
capture, and Web export checks.

### Visual

Capture and inspect:

- Training briefing.
- Intent-reading step.
- Defense-card step.
- End-turn step.
- Each engineering-chain card step.
- Tutorial completion.
- Desktop and mobile forced tutorial URLs.

Browser verification checks `?tutorial=1`, both reference viewport sizes,
nonblank canvas output, the transition into the formal map, and console errors.

## Acceptance Criteria

1. A first-time player must perform the core combat actions rather than only
   read instructions.
2. The player experiences intent, defense, end turn, raw data, trusted data,
   output response, repair progress, and evidence gating.
3. Tutorial completion leads to an untouched formal starter run.
4. Returning players do not see the tutorial automatically for the same
   tutorial version.
5. Skip is always available and reaches the same clean formal-run state.
6. Node Lab and existing runtime behavior remain isolated and unchanged.
7. Desktop and mobile reference viewports have no covered or unreachable
   tutorial controls.
