# Ch09 Combat Depth And Question Events Design

Date: 2026-07-29

## 1. Goal

Improve the Ch09 graybox from a rules-complete prototype into a deckbuilder whose
normal run has meaningful turn-by-turn decisions.

The player should:

1. Read the fault intent and special rule.
2. Decide whether to defend, counter the rule, or advance the engineering chain.
3. Build a deck that reliably completes collection, interface, processing, and
   output.
4. Answer two seeded question-mark events whose rewards and penalties affect the
   current run.

Chapter knowledge remains part of the game rules rather than optional flavor
text.

## 2. Constraints

- Keep the Ch11/Ch12-aligned project structure: thin scene, one root controller,
  local JSON data, shared runtime, SceneTree tests, and Web export.
- Keep the default route as a single 12-node line.
- Node 11 must always be a pre-Boss service node.
- Node 12 remains the three-phase warehouse acceptance Boss.
- Keep the current processing points, hand, raw data, trusted data, block,
  diagnosis, alarm, and evidence systems.
- Do not add a new permanent combat resource.
- Preserve the interactive tutorial, Node Lab isolation, course reporting, and
  desktop/mobile reference viewports.
- This increment improves the graybox. It does not introduce final artwork or a
  new scene framework.

## 3. Core Combat Loop

### 3.1 Engineering Chain

The four ordered stages are:

```text
collect -> interface -> process -> output
```

Playing the next stage advances the chain. Defense and power cards do not break
the chain. Playing a stage out of order remains legal and resolves the card, but
does not advance the chain reward.

The first time each threshold is reached in a turn:

| Chain | Reward |
| --- | --- |
| 2 stages | Gain 3 block |
| 3 stages | Refund 1 processing point |
| 4 stages | Gain 8 repair and 1 diagnosis |

Every threshold is limited to once per turn. The chain resets at the start of
the next player turn. Existing cards that require a chain value continue to use
the same ordered state.

The encounter UI shows all four stages, the current stage, the next valid stage,
and the pending threshold reward. A card preview states whether playing the card
will advance, preserve, or fail to advance the chain.

### 3.2 Reroute

At the start of every player turn, before the first card is played, the player
may use `重新调度` once:

1. Activate reroute mode.
2. Select one non-negative card in hand.
3. Discard it.
4. Draw one replacement card.

Reroute costs no processing points. It becomes unavailable after the first card
is played or after it is used. The player may cancel reroute mode without
consuming it.

This is a consistency tool, not a guaranteed search. Deck thinning, card draw,
retention, and card selection remain valuable.

### 3.3 Fault Fairness

Every combat presents two pressures:

- `下一行动`: the end-turn damage or negative card.
- `故障规则`: a player-action trigger that creates an additional consequence.

The fault panel must also display `反制方法`. No mandatory encounter rule may
require one exact card ID. Every rule has at least two tag- or behavior-based
counters, and the starter deck has at least two executable answers to every
mandatory route encounter.

Dangerous rules are announced at least one complete player turn before they can
cause an unavoidable consequence. There are no hidden trigger conditions.

## 4. Fault Rules

### 4.1 Ordinary Faults

| Fault | Trigger | Consequence | Counters |
| --- | --- | --- | --- |
| MQ-2 warm-up | Play a second smoke collection before diagnosis or calibration | Add `uncalibrated_reading` | Play diagnosis or calibration first; collect only once |
| BH1750 stale reading | End turn with unconverted light raw data | Replace it with `stale_data` | Convert it; retain it with cache |
| ADC spike noise | Play a second collection card without preparation | Add `abnormal_reading` | Play filter or diagnosis first; collect only once |
| LCD blocking | Play output without buffer, scheduler, or diagnosis preparation | Lose 1 processing point next turn | Prepare with buffer, scheduler, or diagnosis |
| Alarm jitter | Gain an alarm marker without trusted data or filtering | Add `false_alarm` | Produce trusted data; play filter first |

Each ordinary encounter enables one special rule only.

### 4.2 Elite Fault

`I2C bus congestion` triggers when the second I2C card is played in one turn.
It deals 6 stability damage and adds `blocking_delay`.

The trigger is cancelled once that turn by either:

- playing a diagnosis or scheduler card before the second I2C card; or
- reaching a three-stage chain before the second I2C card.

The elite reward contains one engineering component and one three-card reward.

### 4.3 Boss

The Boss keeps three continuous phases:

1. `Collection access`: demonstrate at least two source types.
2. `Trusted data`: convert data and demonstrate filter or calibration.
3. `System closure`: use two different output types; repeated output types have
   diminishing repair.

The deck and stability do not reset between phases. Each phase transition draws
to five cards, clears temporary turn state, and restores reroute availability.

Node 11 shop generation guarantees at least one affordable card for any missing
mandatory Boss stage.

## 5. Card And Deck Changes

### 5.1 Starter Deck

Keep 12 cards. Replace one copy of `unit_convert` with a second copy of
`sliding_average`.

The starter deck therefore contains:

- four collection cards;
- four interface cards;
- one zero-cost conversion card;
- two process/defense cards;
- one output card.

### 5.2 Card Pool

Keep the existing 29 cards, add these 8 cards:

- `polling_scan`;
- `logic_probe`;
- `task_yield`;
- `median_filter`;
- `dma_queue`;
- `trusted_snapshot`;
- `interrupt_trace`;
- `multi_source_dashboard`.

Revise these 6 existing cards:

- `environment_baseline`;
- `i2c_register_read`;
- `uart_log`;
- `outlier_reject`;
- `data_cache`;
- `nonblocking_delay`.

The new or revised cards add:

- draw two, discard one;
- inspect the top three cards and choose one;
- draw after a successful interface conversion;
- draw after removing a negative card;
- retain one selected card;
- retain one trusted datum;
- prepare a fault counter;
- reward multi-source output.

The four supported overlapping archetypes are:

| Archetype | Primary plan | Consistency tool |
| --- | --- | --- |
| Smoke alarm | Build trusted smoke and convert it into alarm output | Draw after consuming smoke |
| I2C multi-sensor | Convert several sensor sources | Select or draw after interface success |
| Diagnostic filtering | Remove negative cards and convert them into value | Draw after negative removal |
| Scheduled closure | Control order and repeatedly complete chains | Draw-discard and card retention |

Processing-point refunds, cost reductions, and draw triggers use per-turn limits
where necessary. Zero-cost draw cards cannot recursively create an infinite
draw or processing-point loop.

### 5.3 Reward Composition

Every normal three-card reward contains:

1. one current-deck synergy card;
2. one missing-chain card;
3. one generic defense, draw, or current-fault counter card.

The reward UI labels these reasons as `协同`, `补链`, or `反制`. The label
explains selection without guaranteeing a specific card.

## 6. Question-Mark Events

### 6.1 Route Placement

Nodes 2 and 6 are question-mark events.

- Node 2 draws one basic event.
- Node 6 draws one advanced event.
- The two events in one run cannot share the same question type or primary
  knowledge tag.
- Selection is seeded. Normal runs vary, while tests and Node Lab can force an
  exact event.

Node 6 replaces the old standalone component node. Advanced correct-answer
rewards can include an engineering component.

### 6.2 Initial Pool

The graybox ships with 16 events:

- 8 basic events about sensors, ADC, I2C, and basic signal chains;
- 8 advanced events about filtering, scheduling, buffering, alarms, and output.

Question types:

1. fault diagnosis;
2. signal-chain ordering;
3. code tracing;
4. parameter selection;
5. waveform interpretation;
6. engineering trade-off.

There is no free-text input. Interaction uses buttons, ordering controls, or
graphical selections that work at 390 x 844.

### 6.3 Resolution

Correct answers show the explanation and then offer two rewards.

Basic reward candidates:

- 20-30 budget;
- restore 6-10 stability;
- choose a common card;
- reveal future-node details.

Advanced reward candidates:

- upgrade a card;
- choose an engineering component;
- choose a targeted uncommon card;
- remove a starter card.

Wrong answers show the correct answer and full explanation before applying one
declared medium penalty:

- lose 6-10 stability;
- lose 15-25 budget; or
- add one removable negative card.

Wrong answers cannot directly end the run, do not reduce the course star score,
and cannot be retried. Stability penalties clamp stability to a minimum of 1;
budget penalties clamp budget to 0.

### 6.4 Event Data

Each event record declares:

```text
id
tier
questionType
knowledgeTags
prompt
content
options
correctAnswer
explanation
rewardChoices
penalty
```

Ordering and waveform events may add structured payload fields, but they use the
same resolution contract.

## 7. Twelve-Node Run

The route order is:

```text
1  ordinary fault
2  basic question event
3  ordinary fault
4  service
5  sensor-access checkpoint
6  advanced question event
7  ordinary fault
8  trusted-data checkpoint
9  shop
10 I2C elite
11 pre-Boss service
12 three-phase Boss
```

The three MVP route seeds keep this node-type order but vary ordinary faults,
event draws, reward candidates, and shop inventory.

## 8. Graybox Interaction Design

### 8.1 Combat

The existing stage-confrontation layout remains:

- device readout on the left;
- repair and evidence bridge in the center;
- fault and intent on the right;
- hand dock at the bottom.

Add:

- a four-stage chain strip directly above the hand;
- a `重新调度 1/1` command beside processing points;
- selection and cancel states for reroute;
- separate `下一行动`, `故障规则`, and `反制方法` rows in the fault panel;
- a short trigger message beside the affected value when a chain reward, fault
  trigger, or counter occurs.

On mobile, fault information remains first, followed by evidence/device state,
the chain strip, and the hand dock. Reroute and end turn remain separate
44-pixel touch targets.

### 8.2 Events

All event types share one frame:

- event title and knowledge tag;
- concise scenario;
- question-specific interaction;
- locked answer state;
- explanation;
- reward or penalty result;
- continue command.

The answer locks immediately after submission. Consequences are not applied
until the explanation is visible, so the player can connect the result to the
knowledge point.

### 8.3 Feedback

Feedback is brief and functional:

- chain stages light in order;
- the refunded processing point moves directly into the counter;
- fault triggers flash the exact rule row;
- successful counters mark the rule as suppressed for the turn;
- negative cards name the action that produced them.

The interface remains understandable when transitions are skipped.

## 9. Architecture

Implementation stays inside the current Ch09 boundaries:

- `scripts/env_spire_root.gd` owns run state and rendering;
- `data/cards.local.json` owns card definitions;
- `data/enemies.local.json` owns fault rules;
- `data/events.local.json` owns the 16 event questions;
- `data/relics.local.json` owns engineering components;
- `data/run_maps.local.json` owns the 12-node seeded routes;
- `dev/node_lab.gd` exposes event and encounter fixtures;
- SceneTree tests exercise public gameplay actions.

New rule data is declarative. The root controller interprets a bounded set of
rule IDs and question types rather than matching enemy or event display names.

Tutorial mode does not enable normal fault rules, random question selection, or
formal reporting.

## 10. Fallback Behavior

- If an event pool cannot provide a non-repeating match, draw any valid event
  from the correct tier and log the relaxed constraint.
- If an event definition is malformed, skip its consequence, show a data error,
  and continue to the next map node.
- If a reward pool is empty, keep a visible leave action.
- If a required Boss counter card is missing from the shop pool, inject the
  cheapest valid common card.
- If reroute cannot draw a replacement because all piles are empty, return the
  selected card to hand and do not consume reroute.
- Missing waveform display data falls back to a text-based reading table rather
  than a blank panel.

## 11. Test Strategy

### 11.1 Rules

- Chain order, threshold rewards, and once-per-turn limits.
- Defense and power cards preserve chain state.
- Reroute works before the first card, can be cancelled, and is rejected after
  a card is played.
- Reroute empty-pile fallback preserves the selected card.
- Every ordinary and elite rule has trigger and counter tests.
- Starter deck can answer every mandatory route rule.
- Added draw and refund effects cannot form a deterministic infinite loop.

### 11.2 Events

- Nodes 2 and 6 draw from the correct tiers.
- Seeded draws are reproducible.
- The two events do not repeat type or primary knowledge tag.
- Correct answers show explanations and grant one selected reward.
- Wrong answers show explanations and apply exactly one medium penalty.
- Wrong answers do not reduce star score or directly end the run.
- All 16 event records satisfy the data contract.

### 11.3 Run And Integration

- All three route seeds complete 12 nodes.
- Node 11 is service and node 12 is Boss.
- Node 6 no longer launches the standalone component state.
- Boss phase gates and missing-link shop guarantees work.
- Tutorial and Node Lab remain isolated from formal completion reporting.
- Existing runtime reset behavior remains correct.

### 11.4 UI And Visual

At 1280 x 720 and 390 x 844:

- chain strip, reroute, hand, and end turn do not overlap;
- all fault-rule rows remain readable;
- every question type has reachable controls;
- explanations and consequences fit or scroll;
- Node Lab can force every event, answer outcome, fault rule, and counter state.

Regenerate native captures, export Web, and perform browser console and canvas
checks for normal run, forced events, combat, Boss, and Node Lab.

## 12. Acceptance Criteria

1. Every normal combat turn presents a visible choice between defense, fault
   counterplay, and engineering-chain progress.
2. A bad five-card hand can be improved once per turn without guaranteeing the
   perfect answer.
3. Mandatory fault rules never require one exact card ID or a hidden trigger.
4. Four-stage chains are achievable with the starter deck and reward meaningful
   ordering.
5. Nodes 2 and 6 draw different seeded question events in one run.
6. Correct and wrong event answers both teach the underlying knowledge point.
7. Medium penalties matter during the run but do not directly determine course
   stars.
8. The default 12-node line, pre-Boss service, Boss, tutorial, Node Lab,
   reporting, desktop layout, and mobile layout remain functional.
