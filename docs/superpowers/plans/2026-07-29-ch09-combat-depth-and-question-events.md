# Ch09 Combat Depth And Question Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Ch09 graybox into a tactically reliable deckbuilder with ordered engineering-chain rewards, one reroute per turn, explicit fault counterplay, expanded card consistency, and seeded question events at nodes 2 and 6.

**Architecture:** Preserve the thin `main.tscn`, single `env_spire_root.gd` controller, local JSON data, shared `dgbook_runtime`, and SceneTree tests used by Ch11/Ch12. New combat and event behavior is data-driven through bounded rule IDs and question types; the controller remains the only gameplay state owner, while Node Lab exposes deterministic fixtures for every new state.

**Tech Stack:** Godot 4.6 GDScript, JSON content files, SceneTree command-line tests, native Godot capture scripts, Web export.

## Global Constraints

- Keep the default route as one 12-node line.
- Nodes 2 and 6 are seeded question events; their question type and primary knowledge tag cannot repeat in one run.
- Node 11 is always pre-Boss service and node 12 is always the three-phase Boss.
- Keep 3 processing points, 5-card hands, and the existing raw/trusted data, block, diagnosis, alarm, and evidence resources.
- Do not add a permanent combat resource or a new scene framework.
- Keep the current tutorial behavior and keep tutorial, Node Lab, and formal reporting isolated.
- Preserve exact responsive references at 1280 x 720 and 390 x 844.
- Use tests first for every behavior change and observe the expected RED result before production edits.
- Make local commits only; do not push, merge, or broadly stage unrelated untracked files.

---

## File Structure

**Modify**

- `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`
  - Owns chain rewards, reroute, fault rules, event resolution, reward composition, run integration, and UI rendering.
- `packages/edugame/godot/games/ch09-env-spire/data/cards.local.json`
  - Adds 8 cards and revises 6 cards.
- `packages/edugame/godot/games/ch09-env-spire/data/enemies.local.json`
  - Declares ordinary and elite `faultRule` records.
- `packages/edugame/godot/games/ch09-env-spire/data/events.local.json`
  - Replaces the 4 simple events with the 16 question-event records.
- `packages/edugame/godot/games/ch09-env-spire/data/run_maps.local.json`
  - Changes node 6 from component to advanced question event in all three seeds.
- `packages/edugame/godot/games/ch09-env-spire/data/relics.local.json`
  - Revises the old chain-refund component so it does not duplicate the new
    baseline three-stage reward.
- `packages/edugame/godot/games/ch09-env-spire/dev/node_lab.gd`
  - Groups question events by tier/type and exposes correct/wrong answer fixtures.
- `packages/edugame/godot/games/ch09-env-spire/tests/test_card_rules.gd`
  - Covers chain thresholds, reroute, new effects, and anti-loop limits.
- `packages/edugame/godot/games/ch09-env-spire/tests/test_data_contract.gd`
  - Covers fault-rule, card, event, route, and component schemas.
- `packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd`
  - Covers fault triggers/counters, node order, event results, rewards, and Boss preparation.
- `packages/edugame/godot/games/ch09-env-spire/tests/test_random_robustness.gd`
  - Covers seeded event non-repetition and reward fallback behavior.
- `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
  - Covers chain, reroute, fault rows, event controls, and both viewports.
- `packages/edugame/godot/games/ch09-env-spire/tests/test_node_lab.gd`
  - Covers event catalogs, forced outcomes, fault rules, and isolation.
- `packages/edugame/godot/games/ch09-env-spire/tests/test_full_run.gd`
  - Uses the new node sequence and completes all three seeds.
- `packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd`
  - Captures new combat and six question-type states.
- `packages/edugame/godot/games/ch09-env-spire/README.md`
  - Documents forced event/fault Node Lab testing and capture output.

No new runtime dependency or scene is created.

---

### Task 1: Engineering Chain Rewards And Reroute

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_card_rules.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Produces: `begin_reroute() -> bool`
- Produces: `cancel_reroute() -> bool`
- Produces: `reroute_card(hand_index: int) -> bool`
- Produces: `_chain_preview_for_stage(stage: String) -> Dictionary`
- Produces state: `reroute_available: bool`, `reroute_mode: bool`, `cards_played_this_turn: int`, `chain_rewards_claimed: Dictionary`
- Preserves: `chain_count` values `0..3`, where `1`, `2`, and `3` mean 2-, 3-, and 4-stage thresholds.

- [ ] **Step 1: Add failing chain-threshold tests**

Append focused assertions after starting `mq2_warmup`:

```gdscript
game.block = 0
game.diagnosis = 0
game.repair_progress = 0
game.processing_points = 3
game.chain_count = 0
game.last_stage = ""
game.chain_rewards_claimed.clear()

game.hand = [game._card_copy("mq2_sample")]
_assert(game.play_card(0), "collect should begin the engineering chain")
game.hand = [game._card_copy("adc_convert")]
_assert(game.play_card(0), "interface should reach the two-stage threshold")
_assert(game.chain_count == 1 and game.block == 3, "two stages should grant 3 block once")

game.raw_data["smoke"] = 1
game.hand = [game._card_copy("unit_convert")]
_assert(game.play_card(0), "process should reach the three-stage threshold")
_assert(game.chain_count == 2 and game.processing_points == 2, "three stages should refund one processing point")

game.trusted_data["smoke"] = 1
game.hand = [game._card_copy("uart_log")]
var repair_before_chain: int = game.repair_progress
_assert(game.play_card(0), "output should close the four-stage chain")
_assert(game.chain_count == 3, "output should mark a complete chain")
_assert(game.repair_progress >= repair_before_chain + 8, "complete chain should add 8 repair")
_assert(game.diagnosis == 2, "UART diagnosis plus complete chain should grant two diagnosis")
```

Also assert that a defense or power card with the next valid stage advances the
chain, a card with an empty/neutral stage preserves `last_stage`, and manually
calling `_advance_chain` through the same thresholds a second time in the same
turn does not repeat rewards.

- [ ] **Step 2: Run the card-rule test and verify RED**

Run:

```powershell
godot.cmd --headless --path . -s tests/test_card_rules.gd
```

Expected: FAIL because `chain_rewards_claimed` is absent and thresholds do not
grant the specified baseline rewards.

- [ ] **Step 3: Implement once-per-turn chain rewards**

Add state initialization:

```gdscript
var chain_rewards_claimed := {}
var cards_played_this_turn := 0
var reroute_available := false
var reroute_mode := false
```

Update `_advance_chain(stage)` so `collect` starts at `0`, the next ordered
stage increments regardless of card type, empty/neutral stages preserve
progress, and this helper runs after a successful increment:

```gdscript
func _apply_chain_threshold_rewards() -> void:
	if chain_count >= 1 and !bool(chain_rewards_claimed.get("two", false)):
		block += 3
		chain_rewards_claimed["two"] = true
	if chain_count >= 2 and !bool(chain_rewards_claimed.get("three", false)):
		processing_points += 1
		chain_rewards_claimed["three"] = true
	if chain_count >= 3 and !bool(chain_rewards_claimed.get("four", false)):
		repair_progress = mini(repair_target, repair_progress + 8)
		diagnosis = mini(diagnosis + 1, 3)
		chain_rewards_claimed["four"] = true
```

Remove the old baseline dependency on `state_template` for the three-stage
refund. Revise that component in Task 3 instead of stacking a second refund.

- [ ] **Step 4: Add failing reroute behavior tests**

Use a fixed hand and draw pile:

```gdscript
game._reset_turn_state(true)
game.hand = [game._card_copy("mq2_sample"), game._card_copy("bh1750_read")]
game.draw_pile = [game._card_copy("sliding_average")]
game.discard_pile.clear()
_assert(game.begin_reroute(), "reroute should open before the first card")
_assert(game.reroute_card(0), "reroute should replace one selected card")
_assert(game.hand.size() == 2, "reroute should preserve hand size")
_assert(str((game.hand[1] as Dictionary).get("id", "")) == "sliding_average", "reroute should draw the replacement")
_assert(!game.begin_reroute(), "reroute should be limited to once per turn")

game._reset_turn_state(false)
game.hand = [game._card_copy("mq2_sample")]
game.processing_points = 3
_assert(game.play_card(0), "card should play before late reroute check")
_assert(!game.begin_reroute(), "reroute should lock after the first card")
```

Add an empty-pile case that asserts the selected card returns to hand and
`reroute_available` remains true.

- [ ] **Step 5: Run the card-rule test and verify reroute RED**

Run the same command. Expected: FAIL because the three public reroute methods do
not exist.

- [ ] **Step 6: Implement reroute and turn reset**

Implement:

```gdscript
func begin_reroute() -> bool:
	if state != RunState.COMBAT or !reroute_available or cards_played_this_turn > 0:
		return false
	reroute_mode = true
	_render_state()
	return true

func cancel_reroute() -> bool:
	if !reroute_mode:
		return false
	reroute_mode = false
	_render_state()
	return true

func reroute_card(hand_index: int) -> bool:
	if !reroute_mode or hand_index < 0 or hand_index >= hand.size():
		return false
	var card := hand[hand_index] as Dictionary
	if bool(card.get("negative", false)):
		return false
	hand.remove_at(hand_index)
	discard_pile.append(card)
	var before_draw := hand.size()
	_draw_cards(1)
	if hand.size() == before_draw:
		discard_pile.erase(card)
		hand.insert(hand_index, card)
		reroute_mode = false
		return false
	reroute_available = false
	reroute_mode = false
	_render_state()
	return true
```

Increment `cards_played_this_turn` only after a successful `play_card`. In
`_reset_turn_state`, clear chain threshold flags, reset the card count, enable
reroute, and cancel reroute mode. Tutorial practice keeps reroute hidden and
disabled.

- [ ] **Step 7: Add and verify graybox UI contracts**

Add stable nodes:

```text
EngineeringChainStrip
ChainCollect
ChainInterface
ChainProcess
ChainOutput
RerouteButton
RerouteCancelButton
```

Assert both reference viewports keep these nodes visible, keep button heights at
least 44 pixels, and keep reroute/end-turn bounds disjoint.

Run:

```powershell
godot.cmd --headless --path . -s tests/test_card_rules.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: both PASS.

- [ ] **Step 8: Commit Task 1**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_card_rules.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd
git commit -m "feat: add ch09 chain rewards and reroute"
```

---

### Task 2: Data-Driven Fault Rules

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/data/enemies.local.json`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_data_contract.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Consumes: `cards_played_this_turn`, `chain_count`, card `tags`.
- Produces: `fault_rule_state: Dictionary`
- Produces: `_fault_rule_definition() -> Dictionary`
- Produces: `_fault_rule_preview() -> Dictionary`
- Produces: `_prepare_fault_rule_for_card(card: Dictionary) -> void`
- Produces: `_resolve_fault_rule_after_card(card: Dictionary) -> void`
- Produces: `_resolve_fault_rule_end_turn() -> void`

- [ ] **Step 1: Add failing enemy-schema tests**

Require all non-Boss enemies to declare:

```gdscript
var rule := enemy.get("faultRule", {}) as Dictionary
_assert(!rule.is_empty(), "%s should declare faultRule" % enemy.get("id", "enemy"))
_assert(!str(rule.get("id", "")).is_empty(), "fault rule should have an id")
_assert(!str(rule.get("description", "")).is_empty(), "fault rule should explain its trigger")
_assert(!str(rule.get("counterText", "")).is_empty(), "fault rule should explain its counter")
_assert((rule.get("counterTags", []) as Array).size() >= 2 or bool(rule.get("behaviorCounter", false)), "fault rule should have broad counterplay")
```

- [ ] **Step 2: Run data-contract test and verify RED**

```powershell
godot.cmd --headless --path . -s tests/test_data_contract.gd
```

Expected: FAIL because enemy records do not declare `faultRule`.

- [ ] **Step 3: Add exact fault-rule data**

Add:

```json
"faultRule": {
  "id": "mq2_uncalibrated",
  "timing": "after_card",
  "triggerTag": "smoke",
  "triggerCount": 2,
  "counterTags": ["diagnosis", "calibration"],
  "behaviorCounter": true,
  "negativeCard": "uncalibrated_reading",
  "description": "本回合第 2 次烟雾采集会加入未校准读数。",
  "counterText": "先诊断/校准，或本回合只采集一次。"
}
```

Use corresponding rule IDs:

```text
bh1750_stale_raw       timing=end_turn, source=light, negative=stale_data
adc_second_collect     timing=after_card, triggerStage=collect, count=2, counters=filter/diagnosis
lcd_unprepared_output  timing=after_card, triggerStage=output, counters=buffer/scheduler/diagnosis, nextEnergy=-1
alarm_without_trust    timing=after_card, triggerTag=alarm, counters=filter/trusted_data, negative=false_alarm
i2c_second_transaction timing=after_card, triggerTag=i2c, count=2, counters=diagnosis/scheduler/chain3, damage=6, negative=blocking_delay
```

- [ ] **Step 4: Add failing trigger/counter tests**

For each rule, start its encounter twice:

```gdscript
game._start_encounter("i2c_congestion", "elite")
game.hand = [game._card_copy("i2c_transaction"), game._card_copy("i2c_register_read")]
game.processing_points = 3
var stability_before_rule: int = game.stability
_assert(game.play_card(0), "first I2C card should be safe")
_assert(game.play_card(0), "second I2C card should resolve")
_assert(game.stability == stability_before_rule - 6, "uncountered congestion should deal 6")
_assert(game._pile_has_card("blocking_delay"), "uncountered congestion should add blocking delay")

game._start_encounter("i2c_congestion", "elite")
game.hand = [game._card_copy("uart_log"), game._card_copy("i2c_transaction"), game._card_copy("i2c_register_read")]
game.processing_points = 4
var protected_stability: int = game.stability
_assert(game.play_card(0), "diagnosis card should prepare the counter")
_assert(game.play_card(0) and game.play_card(0), "two I2C cards should play")
_assert(game.stability == protected_stability, "diagnosis should suppress congestion once")
```

Add equivalent tests for the ordinary rule trigger and at least one allowed
counter. For BH1750, call `end_turn()` with light raw data and then with cache
retention.

- [ ] **Step 5: Run run-flow test and verify RED**

```powershell
godot.cmd --headless --path . -s tests/test_run_flow.gd
```

Expected: FAIL because fault-rule state and triggers are not implemented.

- [ ] **Step 6: Implement the bounded fault-rule interpreter**

At encounter start:

```gdscript
fault_rule_state = {
	"cardTagCounts": {},
	"stageCounts": {},
	"suppressed": false,
	"triggered": false,
	"nextEnergyPenalty": 0
}
```

Before card effects, set `suppressed` when card tags intersect `counterTags`.
After card effects, count trigger tags/stages and resolve only the active rule
ID. At end turn, resolve `bh1750_stale_raw` and apply queued next-turn energy
penalties. Reset per-turn counts and suppression in `_reset_turn_state`.

Use `_negative_card(id)` and `_take_damage(amount)` so existing pile and block
rules remain authoritative. Log the exact trigger and exact counter.

- [ ] **Step 7: Render rule, counter, and suppression state**

Create stable labels:

```text
FaultIntentRow
FaultRuleRow
FaultCounterRow
FaultRuleState
```

`FaultRuleState` displays `待触发`, `本回合已抑制`, or `已触发`. Update
`test_graybox_ui.gd` to assert readable non-empty text and non-overlap at both
viewports.

- [ ] **Step 8: Run focused and existing combat tests**

```powershell
godot.cmd --headless --path . -s tests/test_data_contract.gd
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_card_rules.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: all PASS.

- [ ] **Step 9: Commit Task 2**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/data/enemies.local.json packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_data_contract.gd packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd
git commit -m "feat: add ch09 fault counterplay"
```

---

### Task 3: Card Consistency And Reward Composition

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/data/cards.local.json`
- Modify: `packages/edugame/godot/games/ch09-env-spire/data/relics.local.json`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_data_contract.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_card_rules.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_random_robustness.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Produces effects: `draw_discard`, `select_draw`, `retain_card`, `draw_if_removed`, `prepare_counter`, `multi_source_repair`.
- Produces: `pending_card_selection: Dictionary`
- Produces: `choose_pending_card(index: int) -> bool`
- Produces: `_reward_reason(card: Dictionary) -> String`
- Consumes: chain and fault-rule interfaces from Tasks 1-2.

- [ ] **Step 1: Add failing card-pool and starter-deck tests**

Require exactly 37 non-negative playable cards and the eight new IDs:

```gdscript
for card_id in [
	"polling_scan", "logic_probe", "task_yield", "median_filter",
	"dma_queue", "trusted_snapshot", "interrupt_trace", "multi_source_dashboard"
]:
	_assert(card_ids.has(card_id), "card pool should contain %s" % card_id)

_assert(card_ids.size() == 37, "graybox card pool should contain 37 playable cards")
var starter_ids: Array = game.get_script().get_script_constant_map().get("STARTER_CARD_IDS", [])
_assert(starter_ids.count("unit_convert") == 1, "starter deck should keep one unit conversion")
_assert(starter_ids.count("sliding_average") == 2, "starter deck should contain two filters")
```

Require all draw/refund effects to declare `perTurnLimit` when they can combine
with a zero-cost card.

- [ ] **Step 2: Run data/card tests and verify RED**

```powershell
godot.cmd --headless --path . -s tests/test_data_contract.gd
godot.cmd --headless --path . -s tests/test_card_rules.gd
```

Expected: FAIL because the eight IDs and revised starter deck are absent.

- [ ] **Step 3: Add the eight cards and revise six cards**

Add exact functional roles:

| ID | Cost/stage | Rule |
| --- | --- | --- |
| `polling_scan` | 1/collect | Gain one chosen raw source, draw 2, then discard 1 |
| `logic_probe` | 0/interface | Inspect top 3, choose 1, gain 1 diagnosis, exhaust |
| `task_yield` | 1/process | Gain 6 block, draw 1, next interface costs 1 less |
| `median_filter` | 1/process | Remove one noise card; if removed, draw 1; gain 5 repair |
| `dma_queue` | 1/process | Retain one selected hand card; gain 5 block |
| `trusted_snapshot` | 1/process | Retain data this turn, draw 1 |
| `interrupt_trace` | 1/output | If the fault is suppressed, draw 1 and repair 8; otherwise repair 4 |
| `multi_source_dashboard` | 2/output | Consume up to 2 different trusted sources; repair 8 per source |

Revise:

```text
environment_baseline  upgrade inspects top 3 and chooses 1
i2c_register_read     successful conversion draws 1, once per turn
uart_log              keeps draw 1; upgrade also prepares diagnosis counter
outlier_reject        draws 1 when it removes a negative
data_cache             retains data and one selected card instead of drawing 2
nonblocking_delay      draws 1 only when blocking_delay is removed
```

Replace one starter `unit_convert` with `sliding_average`.
Change relic `state_template` from baseline chain-energy refund to
`chain_draw`: the first complete four-stage chain each turn draws one card.

- [ ] **Step 4: Add failing selection/effect tests**

Test real public selection:

```gdscript
game.draw_pile = [
	game._card_copy("mq2_sample"),
	game._card_copy("sliding_average"),
	game._card_copy("uart_log")
]
game.hand = [game._card_copy("logic_probe")]
game.processing_points = 3
_assert(game.play_card(0), "logic probe should open top-three selection")
_assert(game.pending_card_selection.get("kind", "") == "draw_one", "logic probe should expose draw-one selection")
_assert(game.choose_pending_card(1), "one inspected card should be selectable")
_assert(game._hand_has_card("sliding_average"), "selected inspected card should enter hand")
```

Test draw-discard, retained-card return, draw-after-removal, and distinct-source
consumption. Simulate 20 card plays with all refund powers enabled and assert
processing points and hand size remain bounded.

- [ ] **Step 5: Run card-rule test and verify RED**

Expected: FAIL because new effects and `choose_pending_card` are absent.

- [ ] **Step 6: Implement bounded card-selection effects**

Use `pending_card_selection` as a modal gameplay state without adding a new
`RunState`. Disable normal card play and end turn while a selection is open.
Return unchosen inspected cards to the top of the draw pile in their original
relative order. Store retained cards in `retained_cards` and restore them before
normal draw at the next turn.

Track per-turn effect IDs in `turn_effect_uses`. Reject repeated limited effects
without consuming extra draw/refund benefits.

- [ ] **Step 7: Add failing reward-reason tests**

After `_open_reward()`, assert:

```gdscript
_assert(game.reward_choices.size() == 3, "reward should contain three cards")
var reasons := {}
for raw_card in game.reward_choices:
	reasons[game._reward_reason(raw_card as Dictionary)] = true
_assert(reasons.has("协同"), "reward should include current-deck synergy")
_assert(reasons.has("补链"), "reward should include a missing-chain card")
_assert(reasons.has("反制"), "reward should include defense, draw, or fault counterplay")
```

- [ ] **Step 8: Implement deterministic reward buckets and fallbacks**

Build three candidate arrays using deck tags, missing stages, and active fault
counter tags. Pick one unique card from each with the run RNG. When a bucket is
empty, draw a unique non-starter card from the full pool. Store the reason on
the reward copy as `rewardReason`.

Update reward card text to display the reason label.

- [ ] **Step 9: Run focused tests**

```powershell
godot.cmd --headless --path . -s tests/test_data_contract.gd
godot.cmd --headless --path . -s tests/test_card_rules.gd
godot.cmd --headless --path . -s tests/test_random_robustness.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: all PASS.

- [ ] **Step 10: Commit Task 3**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/data/cards.local.json packages/edugame/godot/games/ch09-env-spire/data/relics.local.json packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_card_rules.gd packages/edugame/godot/games/ch09-env-spire/tests/test_data_contract.gd packages/edugame/godot/games/ch09-env-spire/tests/test_random_robustness.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd
git commit -m "feat: expand ch09 card consistency"
```

---

### Task 4: Seeded Question Event Engine And Sixteen Events

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/data/events.local.json`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_data_contract.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_random_robustness.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Produces: `run_seed: int`, initialized from the active map `seedId` and
  overridable by tests/Node Lab.
- Produces: `event_history: Array[Dictionary]`
- Produces: `event_answer_locked: bool`
- Produces: `event_result: Dictionary`
- Produces: `_select_question_event(tier: String, node_id: String) -> Dictionary`
- Produces: `submit_event_answer(answer: Variant) -> bool`
- Produces: `choose_event_reward(index: int) -> bool`
- Produces: `continue_event() -> bool`
- Produces: `_apply_event_consequence(effect: Dictionary) -> bool`
- Replaces normal-run use of `choose_event_option`; keep that method as a
  Node-Lab/backward-compatible wrapper only for legacy simple events.

- [ ] **Step 1: Add failing 16-event data-contract tests**

Require exactly eight `basic` and eight `advanced` records. Validate:

```gdscript
for raw_event in events:
	var event := raw_event as Dictionary
	_assert(["basic", "advanced"].has(str(event.get("tier", ""))), "event tier should be basic or advanced")
	_assert([
		"diagnosis", "ordering", "code_trace", "parameter", "waveform", "tradeoff"
	].has(str(event.get("questionType", ""))), "event should use a supported question type")
	_assert(!(event.get("knowledgeTags", []) as Array).is_empty(), "event should declare knowledge tags")
	_assert(event.has("correctAnswer"), "event should declare the answer")
	_assert(!str(event.get("explanation", "")).is_empty(), "event should explain the answer")
	_assert((event.get("rewardChoices", []) as Array).size() == 2, "event should offer two correct-answer rewards")
	_assert(!(event.get("penalty", {}) as Dictionary).is_empty(), "event should declare one wrong-answer penalty")
```

- [ ] **Step 2: Run data-contract test and verify RED**

Expected: FAIL because the current four events use the old option-only schema.

- [ ] **Step 3: Author the exact event pool**

Basic IDs and content:

| ID | Type | Correct answer | Rewards | Penalty |
| --- | --- | --- | --- | --- |
| `basic_mq2_warmup` | diagnosis | `insufficient_warmup` from `insufficient_warmup / adc_resolution / lcd_refresh` | budget +20 / stability +6 | stability -6 |
| `basic_signal_order` | ordering | `sensor,interface,convert,output` | choose common / budget +25 | add `stale_data` |
| `basic_adc_spike` | waveform | `spike_noise` from `spike_noise / steady_drift / periodic_signal` | choose common filter / reveal nodes 3-4 | stability -6 |
| `basic_i2c_pullup` | diagnosis | `inspect_pullups` from `inspect_pullups / change_sample_period / clear_lcd` | budget +20 / reveal nodes 3-4 | budget -15 |
| `basic_raw_trusted` | tradeoff | `convert_then_validate` from `convert_then_validate / alarm_raw / display_raw` | choose common process / stability +8 | add `uncalibrated_reading` |
| `basic_sample_period` | parameter | `nonblocking_500ms` from `blocking_10ms / nonblocking_500ms / blocking_5s` | budget +25 / stability +6 | stability -6 |
| `basic_i2c_result` | code_trace | `retry_and_log` from `use_stale_value / retry_and_log / refresh_lcd` | choose common diagnosis / budget +20 | add `i2c_nack` |
| `basic_sensor_interface` | parameter | `mq2_adc_others_i2c` from `all_adc / mq2_adc_others_i2c / all_uart` | reveal nodes 3-4 / choose common interface | budget -15 |

Advanced IDs and content:

| ID | Type | Correct answer | Rewards | Penalty |
| --- | --- | --- | --- | --- |
| `advanced_moving_average` | waveform | `reduce_spike_add_delay` from `reduce_spike_add_delay / remove_all_delay / amplify_spike` | upgrade process / component `window_n8` | stability -8 |
| `advanced_address_shift` | code_trace | `write_byte_0x46` from `write_byte_0x23 / write_byte_0x46 / read_byte_0x47` for 7-bit address `0x23` | gain upgraded `address_shift` / remove starter | add `stale_data` |
| `advanced_nonblocking_loop` | code_trace | `millis_state_machine` from `delay_loop / millis_state_machine / lcd_clear_loop` | component `state_template` / choose uncommon scheduler | stability -10 |
| `advanced_display_buffer` | tradeoff | `separate_sample_refresh` from `refresh_every_sample / separate_sample_refresh / disable_sampling` | component `lcd_buffer` / upgrade output | budget -20 |
| `advanced_alarm_hysteresis` | parameter | `on70_off60` from `on70_off70 / on70_off60 / on60_off70` | choose uncommon alarm / remove starter | add `false_alarm` |
| `advanced_outlier_reject` | waveform | `reject_isolated_before_average` from `average_everything / reject_isolated_before_average / publish_peak` | upgrade process / component `window_n8` | add `abnormal_reading` |
| `advanced_polling_order` | ordering | `schedule,sample,convert,validate,publish` | component `serial_helper` / choose uncommon chain card | stability -8 |
| `advanced_uart_report` | diagnosis | `timestamp_status_raw_trusted` from `value_only / timestamp_status_raw_trusted / lcd_text_only` | upgrade output / remove starter | budget -25 |

Waveform payloads are fixed:

```text
basic_adc_spike.samples = [20, 21, 20, 79, 21, 20]
advanced_moving_average.raw = [20, 21, 70, 22, 21]
advanced_moving_average.filtered = [20, 20, 37, 38, 37]
advanced_outlier_reject.samples = [48, 49, 50, 121, 49, 50]
```

Stability penalties use `minimum: 1`; budget penalties use `minimum: 0`.

- [ ] **Step 4: Add failing seeded-selection tests**

```gdscript
game.run_seed = 901
game.event_history.clear()
var basic := game._select_question_event("basic", "a2")
game.event_history.append(basic)
var advanced := game._select_question_event("advanced", "a6")
_assert(str(basic.get("tier", "")) == "basic", "node two should draw basic")
_assert(str(advanced.get("tier", "")) == "advanced", "node six should draw advanced")
_assert(basic.get("questionType") != advanced.get("questionType"), "event types should not repeat")
_assert((basic.get("knowledgeTags", []) as Array)[0] != (advanced.get("knowledgeTags", []) as Array)[0], "primary knowledge tags should not repeat")

game.event_history.clear()
game.run_seed = 901
_assert(game._select_question_event("basic", "a2").get("id") == basic.get("id"), "same seed and node should reproduce event")
```

- [ ] **Step 5: Run robustness test and verify RED**

Expected: FAIL because the selector and history do not exist.

- [ ] **Step 6: Implement seeded selection and relaxed fallback**

Hash `run_seed` plus `node_id`, sort eligible IDs before selection, and filter
out history question types and primary tags. If filtering empties the tier,
select from the sorted full tier and log `事件去重约束已放宽`.

- [ ] **Step 7: Add failing answer-resolution tests**

Use one forced diagnosis event:

```gdscript
game.current_event = game.event_defs["basic_mq2_warmup"].duplicate(true)
game.state = game.RunState.EVENT
var stability_before_wrong: int = game.stability
_assert(!game.continue_event(), "event should not continue before an answer")
_assert(game.submit_event_answer("adc_resolution"), "wrong answer should lock")
_assert(game.event_answer_locked, "answer should lock immediately")
_assert(!bool(game.event_result.get("correct", true)), "wrong answer should be recorded")
_assert(str(game.event_result.get("explanation", "")).length() > 0, "wrong answer should show explanation")
_assert(game.stability >= 1 and game.stability < stability_before_wrong, "wrong stability penalty should matter but not end run")
_assert(game.continue_event() and game.state == game.RunState.MAP, "wrong explained result should continue to the map")
```

For a correct answer, assert that two rewards appear, only one can be selected,
and `continue_event()` returns to the map after resolution.

Also force an event with an empty `options` array and assert it displays
`事件数据无效`, applies no reward or penalty, and enables a safe continue back
to the map.

- [ ] **Step 8: Implement answer, explanation, reward, and penalty states**

Apply no consequence until answer validation has produced `event_result`.
Correct answers set `rewardPending=true`; wrong answers apply exactly one
declared penalty and set `resolved=true`. Clamp stability and budget as specified.
Malformed events resolve to a visible data-error result with no consequence and
a working continue command.

Implement ordering answers as arrays of IDs and all other answers as selected
option IDs, not localized display strings.

`_apply_event_consequence` supports this exact bounded operation set:

```text
budget
heal
add_negative
reveal_nodes
choose_card
add_upgraded_card
upgrade_card
remove_card
choose_component
```

Card and component choices reuse `pending_card_selection` from Task 3 and the
existing component-choice data. The event remains the owning state until that
pending choice resolves.

- [ ] **Step 9: Build the shared event UI**

Create stable nodes:

```text
QuestionEventFrame
QuestionKnowledgeTag
QuestionPrompt
QuestionInteraction
QuestionSubmit
QuestionExplanation
QuestionConsequence
QuestionContinue
```

For waveform events, render the structured sample values with `Line2D`; if the
payload is absent, render a compact reading table. Ordering uses move-up and
move-down icon buttons with 44-pixel targets.

- [ ] **Step 10: Run focused event tests**

```powershell
godot.cmd --headless --path . -s tests/test_data_contract.gd
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_random_robustness.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: all PASS.

- [ ] **Step 11: Commit Task 4**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/data/events.local.json packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_data_contract.gd packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd packages/edugame/godot/games/ch09-env-spire/tests/test_random_robustness.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd
git commit -m "feat: add ch09 seeded question events"
```

---

### Task 5: Route, Boss Preparation, And Node Lab Integration

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/data/run_maps.local.json`
- Modify: `packages/edugame/godot/games/ch09-env-spire/dev/node_lab.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_node_lab.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_runtime_integration.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_full_run.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Consumes: Task 4 event selector and resolution API.
- Produces: `_missing_boss_stage_tags() -> Array[String]`
- Produces: `_guaranteed_boss_shop_card_id() -> String`
- Extends: `start_lab_scenario(entry, deck_fixture)` for `question_event`,
  `question_correct`, `question_wrong`, and `fault_rule` fixture entries.

- [ ] **Step 1: Add failing route-order tests**

For each map:

```gdscript
var expected_types := [
	"ordinary", "event", "ordinary", "service",
	"checkpoint_sensor", "event", "ordinary", "checkpoint_trust",
	"shop", "elite", "service", "boss"
]
for index in range(expected_types.size()):
	var layer := (map.get("layers", []) as Array)[index] as Dictionary
	var choice := (layer.get("choices", []) as Array)[0] as Dictionary
	_assert(str(choice.get("type", "")) == expected_types[index], "%s layer %d should use %s" % [map.get("id"), index + 1, expected_types[index]])
	if index == 1:
		_assert(str(choice.get("eventTier", "")) == "basic", "node two should request a basic event")
	if index == 5:
		_assert(str(choice.get("eventTier", "")) == "advanced", "node six should request an advanced event")
```

- [ ] **Step 2: Run data/run tests and verify RED**

Expected: FAIL because node 6 is still `component`.

- [ ] **Step 3: Update all three route maps**

Set node 2 to `contentId: "random_basic"` and `eventTier: "basic"`. Set node 6
to `type: "event"`, `contentId: "random_advanced"`, and
`eventTier: "advanced"`. Preserve node 11 service and node 12 Boss.

Update `choose_node` to call `_select_question_event` for random event content.
Keep direct event IDs supported for Node Lab.

- [ ] **Step 4: Add failing Boss-shop guarantee tests**

Construct decks missing each mandatory capability:

```gdscript
game.deck = [game._card_copy("mq2_sample")]
_assert(!game._missing_boss_stage_tags().is_empty(), "one-source deck should expose Boss gaps")
game.budget = 35
game.current_layer = 8
game._open_shop()
var guaranteed_id := game._guaranteed_boss_shop_card_id()
_assert(_array_has_id(game.shop_cards, guaranteed_id), "node nine shop should inject a missing-link card")
var guaranteed_price := 999
for raw_card in game.shop_cards:
	var shop_card := raw_card as Dictionary
	if str(shop_card.get("id", "")) == guaranteed_id:
		guaranteed_price = int(shop_card.get("price", 999))
_assert(guaranteed_price <= game.budget, "guaranteed card should be affordable")
```

- [ ] **Step 5: Implement missing-link shop injection**

Evaluate source, trusted/filter, and output coverage from deck tags. Choose the
cheapest common/uncommon card that fills the first missing stage. At node 9 or a
shop opened from node 11 service, inject it if absent and cap its displayed
price at the current budget.

- [ ] **Step 6: Add failing Node Lab catalog tests**

Require:

```text
基础题事件: 8 entries
进阶题事件: 8 entries
题目结果: correct and wrong fixtures
故障规则: one entry per non-Boss fault
```

Launching a result fixture must keep `node_lab_active=true`,
`formal_run_active=false`, and produce no `DGB_GODOT_COMPLETE` payload after
continue/restart/reset.

- [ ] **Step 7: Implement Node Lab fixtures**

Group event entries by tier and question type. Add toolbar controls to force
correct/wrong answer state without changing the underlying correct answer.
Fault-rule entries open the combat with a deterministic hand that can either
trigger or counter the rule.

- [ ] **Step 8: Update full-run bot**

At event nodes, read `correctAnswer`, submit it, choose the first reward, and
continue. Use reroute only when the bot cannot play a card that advances the
current required gate. Update the bot for node 6 event and component rewards
inside advanced events.

- [ ] **Step 9: Run route, Node Lab, runtime, and full runs**

```powershell
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_node_lab.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_a
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_b
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_c
```

Expected: all PASS; every route reports 12 visited nodes, both checkpoints, and
score at least 60.

- [ ] **Step 10: Commit Task 5**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/data/run_maps.local.json packages/edugame/godot/games/ch09-env-spire/dev/node_lab.gd packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd packages/edugame/godot/games/ch09-env-spire/tests/test_run_flow.gd packages/edugame/godot/games/ch09-env-spire/tests/test_node_lab.gd packages/edugame/godot/games/ch09-env-spire/tests/test_runtime_integration.gd packages/edugame/godot/games/ch09-env-spire/tests/test_full_run.gd
git commit -m "feat: integrate ch09 question route"
```

---

### Task 6: Graybox Completion, Captures, Documentation, And Full Verification

**Files:**
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd`
- Modify: `packages/edugame/godot/games/ch09-env-spire/README.md`
- Modify only if verification exposes a tested defect:
  `packages/edugame/godot/games/ch09-env-spire/scripts/env_spire_root.gd`

**Interfaces:**
- Consumes all prior public gameplay and Node Lab interfaces.
- Produces stable native screenshots for combat/reroute/fault/event states.
- Does not introduce new gameplay behavior without a failing regression test.

- [ ] **Step 1: Add final responsive assertions**

At both reference sizes assert:

```text
FaultIntentRow, FaultRuleRow, FaultCounterRow fit inside fault panel
EngineeringChainStrip sits above the hand dock
RerouteButton and EndTurnButton are disjoint and at least 44 px high
QuestionPrompt and QuestionInteraction are visible
QuestionExplanation and QuestionConsequence scroll rather than clip
ordering up/down controls are reachable
waveform plot or fallback table is nonblank
Node Lab toolbar remains above all scenario content
```

- [ ] **Step 2: Run the UI test on the integrated graybox**

```powershell
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
```

Expected: PASS. If a new assertion fails, keep the failing assertion as the
regression test, make the smallest layout correction, and rerun until PASS.

- [ ] **Step 3: Finish graybox responsive behavior**

Use container minimum sizes and scroll containers. Do not reduce body text below
the existing readable sizes. Preserve the existing top HUD and footer. On
mobile, use this vertical order:

```text
fault intent/rule/counter
repair and evidence
device values
engineering chain
processing + reroute + end turn
horizontal hand
footer
```

- [ ] **Step 4: Extend the capture script**

Capture, with asserted transitions and exact state checks:

```text
desktop/mobile normal combat
desktop/mobile reroute selection
desktop/mobile fault triggered
desktop/mobile fault suppressed
desktop/mobile basic diagnosis event
desktop/mobile ordering event
desktop/mobile code-trace event
desktop/mobile parameter event
desktop/mobile waveform event
desktop/mobile trade-off event
desktop/mobile correct explanation/reward
desktop/mobile wrong explanation/penalty
desktop/mobile Node Lab event catalog
```

Retain existing tutorial, route, reward, shop, service, checkpoints, Boss phases,
result, and Node Lab capture filenames.

- [ ] **Step 5: Update README**

Document:

```powershell
godot.cmd --path . -- --node-lab
godot.cmd --headless --path . -s tests/test_card_rules.gd
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --path . -s tests/capture_graybox.gd
godot.cmd --path . -s tests/capture_graybox.gd -- --mobile
```

Explain that Node Lab can force every question type, answer result, fault
trigger, and fault counter.

- [ ] **Step 6: Run the complete automated suite**

```powershell
godot.cmd --headless --path . -s tests/test_data_contract.gd
godot.cmd --headless --path . -s tests/test_card_rules.gd
godot.cmd --headless --path . -s tests/test_tutorial.gd
godot.cmd --headless --path . -s tests/test_run_flow.gd
godot.cmd --headless --path . -s tests/test_random_robustness.gd
godot.cmd --headless --path . -s tests/test_graybox_ui.gd
godot.cmd --headless --path . -s tests/test_runtime_integration.gd
godot.cmd --headless --path . -s tests/test_node_lab.gd
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_a
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_b
godot.cmd --headless --path . -s tests/test_full_run.gd -- --map=mvp_c
```

Expected: every command exits 0.

- [ ] **Step 7: Export Web and generate captures**

```powershell
godot.cmd --headless --path . --export-release Web
godot.cmd --path . -s tests/capture_graybox.gd
godot.cmd --path . -s tests/capture_graybox.gd -- --mobile
```

Expected: Web export exits 0; every capture is nonblank and has exact dimensions
1280 x 720 or 390 x 844.

- [ ] **Step 8: Browser verification**

Serve the exported build, then verify:

```text
normal first-run/tutorial transition
formal map nodes 2 and 6 show question marks
one complete combat with reroute, chain, trigger, and counter
one correct and one wrong event
Node Lab event/fault fixtures
canvas dimensions at desktop and mobile
no console warnings or errors
```

- [ ] **Step 9: Commit Task 6**

```powershell
git add -- packages/edugame/godot/games/ch09-env-spire/tests/capture_graybox.gd packages/edugame/godot/games/ch09-env-spire/tests/test_graybox_ui.gd packages/edugame/godot/games/ch09-env-spire/README.md
git commit -m "test: verify ch09 combat depth graybox"
```

- [ ] **Step 10: Final hygiene**

Run:

```powershell
git diff --check
git status --short --untracked-files=no
git log -8 --oneline
```

Expected: no tracked modifications remain after the final commit. Existing
unrelated untracked files remain untouched.
