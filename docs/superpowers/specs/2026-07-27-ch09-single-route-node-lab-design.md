# Ch09 Single-Route Run and Node Lab Design

## Goal

Simplify chapter 9 navigation so route planning does not compete with card-building decisions. Every run follows one twelve-node route inspired by the pacing of the Golden Compass route in Slay the Spire 2, while encounter content still varies between deterministic map presets.

Provide a separate Node Lab for quickly playing every possible node variant without entering or altering the normal run.

## Confirmed Decisions

- The normal game uses a single route from the start.
- No relic or event is required to convert the map into a single route.
- Every run has exactly twelve visited nodes.
- A rest node is always placed immediately before the boss.
- Ch11/Ch12-aligned project boundaries remain unchanged: one main scene, one root game loop, local JSON data, shared runtime, and SceneTree tests.

## Twelve-Node Sequence

| Node | Type | Purpose |
| ---: | --- | --- |
| 1 | Ordinary fault | Introduce a region-one sensor problem |
| 2 | Debug event | Offer an early deck or resource trade-off |
| 3 | Ordinary fault | Test the other region-one sensor family |
| 4 | Rest | Repair stability, upgrade, or remove a starter card |
| 5 | Sensor checkpoint | Validate sensor acquisition and interface chains |
| 6 | Engineering component | Choose one of three components |
| 7 | Ordinary fault | Introduce a data-reliability or output problem |
| 8 | Trust checkpoint | Validate filtering, calibration, and trustworthy data |
| 9 | Shop | Fill a missing boss tag or improve the deck |
| 10 | Elite fault | Test the assembled deck and award an extra component |
| 11 | Pre-boss rest | Guaranteed final maintenance and deck adjustment |
| 12 | Acceptance boss | Validate acquisition, trustworthy processing, and output |

The sequence is fixed. Each layer contains exactly one choice and links only to the next layer.

## Run Variation

Three deterministic map presets remain available for runtime configuration and automated tests. They share the same node-type sequence but vary the following content:

- the order of MQ-2 and BH1750 ordinary faults;
- the debug event at node 2;
- the region-two or region-three fault at node 7;
- the three components offered at node 6;
- shop inventory and card rewards;
- future elite variants when additional elite data is added.

Variation comes from encounter and reward content, not path topology. The player makes decisions inside rewards, events, components, the shop, and rests.

## Map Presentation

The map remains a progress view rather than a route-planning view.

- Show all twelve nodes in order.
- Distinguish completed, current, and future nodes.
- Only the current node is interactive.
- Keep the current node's title and engineering theme visible.
- Do not display lanes, branch connectors, or unavailable alternatives.
- On narrow screens, keep the current node visible and allow horizontal scrolling without shrinking labels below the existing readable size.

## Engineering Component Node

Node 6 opens the existing choice surface with three unowned engineering components. Choosing one component:

1. adds its relic id to the run;
2. writes a readable log entry;
3. advances directly to node 7.

The elite at node 10 keeps its existing additional component reward. A run can therefore obtain two components before the boss.

If fewer than three unowned components remain, the node shows every remaining component and one card-upgrade fallback.

## Node Lab

### Entry

The Node Lab is a development-only launcher and is never linked from the normal game flow.

- Native launch: pass `--node-lab` after Godot user arguments.
- Web launch: append `?nodeLab=1` to the standalone preview URL.
- Normal host initialization and normal standalone preview remain unchanged when the flag is absent.

### Scenario Catalog

The catalog is generated from the loaded JSON dictionaries so it cannot drift when content is added. It groups scenarios as:

- every ordinary fault;
- every elite fault;
- each boss phase and the full boss;
- every debug event;
- both checkpoints;
- engineering component selection;
- shop;
- rest;
- ordinary and elite reward screens.

### Scenario Fixture

Launching a scenario resets the game to a controlled fixture:

- starter deck;
- full stability;
- 100 engineering budget;
- no components unless the scenario requires one;
- empty encounter evidence and combat piles;
- fixed random seed.

The fixture prevents one scenario from contaminating the next. The lab header provides:

- return to catalog;
- restart current scenario;
- switch between starter deck and a broad-coverage test deck.

The broad-coverage deck contains at least one card for every mandatory knowledge tag. It is only available in the lab.

### Runtime Isolation

Lab sessions do not report completion, score, stars, or learning stats to the shared runtime. Returning to the catalog discards the current scenario. Exiting lab mode and reopening the normal URL starts a fresh normal run.

## Architecture

- `data/run_maps.local.json` owns the fixed twelve-node presets.
- `scripts/env_spire_root.gd` continues to own normal state transitions and exposes narrowly scoped scenario-start helpers.
- `dev/node_lab.gd` owns the development catalog, fixture selection, restart, and return controls.
- The existing main scene and choice/combat views render both normal and lab scenarios.
- No second gameplay implementation or duplicated combat rules are introduced.

## Validation

### Data Contract

- every preset contains exactly twelve layers;
- every layer contains exactly one choice;
- node types match the confirmed sequence;
- node 11 is always `service`;
- node 12 is always `boss`;
- every content id resolves to its corresponding JSON definition.

### Run Flow

- all three deterministic runs visit twelve nodes and reach the boss;
- no node-selection branch is possible;
- node 6 grants one selected component;
- the pre-boss rest cannot be skipped;
- existing knowledge gates and debugging reports remain active.

### Node Lab

- the catalog includes every current encounter and event definition;
- launching each catalog entry reaches the expected state;
- restart restores the fixture exactly;
- returning to the catalog clears scenario state;
- lab completion never calls the runtime result reporter;
- desktop and mobile lab controls do not overlap the reused game views.

