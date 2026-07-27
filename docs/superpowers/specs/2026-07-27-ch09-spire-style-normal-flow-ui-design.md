# Ch09 Normal Run UI Redesign

Date: 2026-07-27

## Goal

Redesign the Ch09 normal run so its information hierarchy and interaction rhythm
feel closer to a Slay the Spire-style deckbuilder while preserving Ch09's bright
engineering/debug identity.

The redesign must make four ideas immediately legible:

1. Where the player is in the 12-node run.
2. Which device and fault are currently in conflict.
3. What the fault will do next.
4. Which cards and engineering evidence can answer it.

## Product Direction

The selected direction is the **stage confrontation layout**.

- Borrow layout principles, not artwork or branding.
- Keep the existing bright, restrained engineering palette.
- Put the device on the left and the fault on the right on desktop.
- Keep cards and turn actions in a stable bottom dock.
- Keep run-level resources in a stable top HUD.
- Turn rewards and service actions into continuations of the run scene instead
  of unrelated form-like pages.

## Scope

### Included

- Normal-run map, combat, reward, event, component, shop, service, checkpoint,
  and result layouts.
- Responsive desktop and mobile composition.
- Scene transitions and clearer state emphasis.
- Reusable UI construction helpers inside the current Ch09 root script.
- UI contract, viewport, full-run, Web export, and browser visual verification.

### Excluded

- Card, enemy, relic, event, or route-balance changes.
- Changes to the 12-node single-route order.
- Changes to runtime reporting or chapter completion rules.
- Dark fantasy artwork or direct visual imitation of Slay the Spire.
- A new scene framework or a rewrite of the Ch09 state machine.
- Changes to Node Lab behavior beyond keeping it compatible.

## Shared Screen Structure

Normal-run states use three persistent layers.

### Run HUD

The top HUD contains only cross-node information:

- Product mark: `ENV / SPIRE`
- Current node and total nodes
- Stability and maximum stability
- Budget
- Deck size

Combat-only values do not appear in the run HUD.

### Scene Stage

The center of the screen changes with the current run state. It must communicate
one primary decision at a time and avoid dashboard-style collections of equal
weight panels.

### Action Dock

Combat uses a permanent bottom hand dock with:

- Processing-point counter on the left
- Horizontally arranged cards in the center
- End-turn command on the right

Non-combat states use the same lower region for their primary action when this
improves continuity, but they do not render an empty card dock.

## State Designs

### Map

The map becomes a centered vertical climb rather than a horizontal table.

- All 12 nodes remain visible or scrollable in one line.
- Completed, current, available-next, and future nodes have distinct states.
- Node 11 is visibly a service node.
- Node 12 is visibly the final acceptance/Boss node.
- A mission summary sits to the left on desktop.
- The selected or next node's details and enter command sit to the right.
- On mobile, the mission summary collapses and node details appear below the
  route.

The map is navigation, not a second dashboard. It does not show combat metrics.

### Combat And Checkpoints

Desktop combat uses a left-to-right confrontation:

- Device/player system on the left
- Repair and evidence bridge in the center
- Fault/enemy on the right
- Enemy intent directly above the fault
- Hand dock across the bottom

The device side shows processing points, defense, combo, diagnosis, and alarm in
a compact readout. The center bridge shows repair progress, raw/trusted data,
and required or collected evidence. The fault side shows name, tier, phase,
health/repair target, and next action.

Checkpoints reuse this scene. Their evidence requirements receive stronger
emphasis, but they do not switch to a separate layout.

### Reward

Reward selection remains visually connected to the resolved encounter.

- The resolved fault and subdued arena remain in the background.
- The top of the reward layer states what was fixed.
- The debugging report explains which evidence or concept mattered.
- Three card choices are centered and visually card-shaped.
- Skip is a secondary command, not a fourth card of equal weight.

### Events, Components, And Shop

These states share a scene-choice presentation:

- One scene title and short context line
- A focused set of choices
- A compact consequence preview where the result is deterministic
- A single exit/back command where applicable

Components remain a three-choice engineering pickup. The shop uses card-sized
inventory items and keeps budget visible in the HUD.

### Service

Service is presented as an engineering maintenance bench, analogous in pacing
to a rest site but specific to the chapter.

- Restore stability
- Upgrade an engineering card
- Enter the equipment shop

Node 11 always uses this screen before the Boss. The rule is unchanged.

### Result

The result screen summarizes the completed ascent:

- Score and completion state
- Stability remaining
- Checkpoint results
- Deck size
- Learning summary
- Restart command

It uses the same visual language as the run rather than a generic report page.

## Responsive Behavior

### Desktop: 1280 x 720 Reference

- Top HUD remains 66 pixels high.
- Combat stage receives the largest vertical share.
- The hand dock is approximately 30 percent of the usable height.
- Cards remain fully visible without overlapping the footer.
- Route, mission summary, and node detail use a three-column map composition.

### Mobile: 390 x 844 Reference

- HUD omits budget and deck size when space is constrained.
- Combat becomes a vertical confrontation: fault and intent first, evidence
  bridge second, device readout third, hand dock last.
- Cards remain horizontally scrollable.
- End turn stays completely above the footer.
- Map route remains centered; secondary summaries collapse below it.
- All commands keep a minimum 44-pixel touch target.

Font sizes do not scale with viewport width. Containers and scroll behavior
handle constrained space.

## Visual Language

- Background: quiet cool-white engineering surface with subtle grid or circuit
  structure.
- Primary: teal for the player system and verified state.
- Threat: coral for faults, enemy intent, and destructive actions.
- Logic: violet for processing and transformation cards.
- Reward/accent: restrained gold.
- Panels use square or lightly rounded corners, never large floating cards.
- Text contrast and hierarchy must remain stronger than background decoration.
- The bundled Chinese font theme applies to every generated UI subtree,
  including Web exports.

## Architecture

The implementation remains within the current Ch11/Ch12-aligned structure:

- Thin `main.tscn`
- Single root controller
- Local JSON data
- Shared `dgbook_runtime`
- SceneTree tests

The root controller keeps the existing `RunState` transitions and gameplay
methods. UI construction is reorganized into focused helpers for:

- Run HUD
- Map climb
- Encounter stage
- Hand dock
- Scene-choice layer
- Result view

Rendering continues to derive from current state. UI helpers do not own gameplay
rules or mutate run progression independently.

Node Lab continues to launch the same state methods. Its toolbar replaces the
normal HUD during lab scenarios, and lab runs remain isolated from runtime
progress and completion reporting.

## Transitions And Feedback

- Entering a node changes from map to scene without an intermediate menu.
- Playing a card gives immediate card, progress, and evidence feedback.
- Ending a turn updates enemy intent before the next player decision.
- Winning transitions to the scene-local reward layer.
- Leaving reward, event, shop, component, or service returns to the route with
  the next node emphasized.

Animations remain brief and functional. The interface must remain understandable
when animation is disabled or skipped.

## Error And Fallback Behavior

- Missing node content uses the existing safe fallback and returns to the map.
- Empty reward or shop pools keep a visible skip/leave action.
- Missing visual assets fall back to styled engineering silhouettes; they never
  produce a blank scene.
- Compact layouts use scrolling before reducing text below readable sizes.
- Node Lab restores normal HUD visibility when returning to the catalog or run.

## Test Strategy

### Automated

- Preserve data-contract, card-rule, random-robustness, runtime, and Node Lab
  tests.
- Add stable node-name assertions for the new HUD, stage, intent, route, hand
  dock, reward layer, and service bench.
- Verify desktop and mobile bounds for HUD, stage, cards, end turn, footer, and
  Node Lab controls.
- Run all three 12-node route fixtures to completion.
- Export Web and verify that the bundled Chinese font reaches every UI subtree.

### Visual

Capture and inspect at both reference sizes:

- Map
- Ordinary combat
- Checkpoint combat
- Reward
- Event
- Shop
- Service
- Boss phases
- Result
- Node Lab catalog and scenario

Browser verification covers normal and Node Lab URLs, canvas dimensions,
nonblank rendering, and console errors.

## Acceptance Criteria

1. A new player can locate run progress, stability, fault intent, repair
   progress, processing points, cards, and end turn without scanning unrelated
   panels.
2. Map, combat, reward, and service feel like consecutive moments in one run.
3. The UI remains recognizably Ch09 engineering/debug rather than a dark fantasy
   imitation.
4. Desktop and mobile reference viewports have no overlapping or unreachable
   controls.
5. The 12-node route, node 11 service, node 12 Boss, card rules, checkpoints,
   Node Lab isolation, and runtime reporting remain behaviorally unchanged.
