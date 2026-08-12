# Ch09 Formal Delivery Checklist

## Repository Structure

Ch09 follows the same Godot package boundaries as Ch11 and Ch12:

- `addons/`: shared host runtime bridge.
- `assets/`: runtime art and fonts; the canonical asset mirror is `packages/edugame/assets/games/ch09-env-spire`.
- `data/`: cards, faults, events, components, maps and synchronized questions.
- `levels/`: course-facing level descriptor and content-addressed entry URL.
- `scenes/`: thin Godot scene entry.
- `scripts/`: state machine, rules, persistence, presentation and UI modules.
- `tests/`: native rules, flow, persistence, UI, capture and recording coverage.

## Include In Version Control

- The complete Ch09 Godot project listed above, including `.gd.uid` and `.import` metadata.
- Canonical Ch09 assets under `packages/edugame/assets/games/ch09-env-spire`.
- Course questions, public synchronized questions and the teaching asset lock.
- Host export/tool/test changes and the generated content-addressed Web package.
- Font source records, Noto Sans SC OFL text and DingTalk authorization notice.
- `artifacts/ch09-env-spire/ch09-env-spire-desktop-full-run-with-tutorial.mp4`.

## Exclude From Version Control

- Godot `.godot/` import cache.
- Repository QA screenshots under `.superpowers/visual-qa/`.
- Recording master AVI and extracted review frames.
- Local save data, settings, logs and temporary preview servers.

## Release Gates

Run from the repository root unless a command changes directory:

```powershell
pnpm.cmd godot:runtime:check
pnpm.cmd godot:teaching:check
pnpm.cmd --filter @dgbook/game test
pnpm.cmd godot:web:export ch09-env-spire
```

Run all Ch09 Godot tests and the three map simulations from this project directory, then execute `tests/capture_graybox.gd` at 1280 x 720. Finally verify the exported Web package in a fresh browser session, check the console, decode the delivery MP4, and run `git diff --check`.

No mobile layout, mobile export preset, branch map, shop economy or meta-progression is part of this delivery.
