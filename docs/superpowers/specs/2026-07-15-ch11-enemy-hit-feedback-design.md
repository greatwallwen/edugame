# Ch11 Band Defense Enemy Hit Feedback Design

## Summary

Upgrade enemy hit feedback by combining a shared mechanical-impact response with restrained tower-specific diagnostic signatures. Remove persistent enemy health bars. Exact health is shown only while hovering an enemy or while viewing diagnosis data.

The result should feel physical and readable without filling the quiet hardware map with overlapping rings, labels, or excessive particles.

## Goals

- Make every effective hit immediately readable through enemy-body motion and localized impact light.
- Distinguish matched attacks from mismatched attacks without relying on floating text alone.
- Give I2C, filter, peak, and low-power towers recognizable impact signatures.
- Replace instant enemy disappearance with a short mechanical shutdown effect.
- Remove persistent health bars while retaining precise health information on demand.
- Preserve existing route movement, damage, reward, wave, and diagnosis behavior.

## Non-Goals

- No global camera shake on normal attacks.
- No repeated global hit-stop that could make multi-tower combat stutter.
- No change to damage values, targeting rules, tower ranges, or enemy speed balance.
- No permanent status labels or extra HUD cards on the gameplay field.
- No large cartoon stars, flat outline bursts, or dense confetti particles.

## Current Behavior

Tower attacks currently subtract health immediately, set a `hitPulse` timer, draw a green or red circular outline, and add floating feedback text. Dead enemies are removed from the active enemy array immediately. Persistent health bars are drawn above every active enemy.

The attack beam and range textures already establish the firing direction, but the enemy sprite has no mechanical recoil, material response, or shutdown phase.

## Hit Event Model

Each resolved hit produces one visual event containing:

- impact world position
- normalized direction from tower to enemy
- tower type and attack style
- matched or mismatched result
- damage amount and lethal status
- elapsed time and total duration

Gameplay damage remains authoritative and is applied before visual effects are created. Visual events never change path progress, targeting, or damage.

## Shared Mechanical Reaction

### Timing

- `0-45 ms`: contact bloom reaches peak brightness and recoil begins.
- `45-110 ms`: enemy body settles from compression and tilt.
- `20-220 ms`: compact tower-specific contact signature settles and fades.
- `220-260 ms`: residual glow disappears.

### Body Motion

For a matched normal hit, the enemy sprite receives a visual-only recoil of approximately 4 px opposite the incoming attack, a maximum tilt of 3 degrees, and a brief scale compression to approximately 0.94 before returning to its route position.

Mismatched hits use no more than 1.5 px recoil, weaker compression, and no strong settle motion. The enemy's logical position is never changed.

A small soft shadow is drawn separately from the sprite during recoil so the body briefly appears to lift or shift rather than slide as a flat image.

## Impact Light

Replace the current full circular hit outline with a localized bitmap impact bloom:

- bright compact core at the contact point
- soft directional flare aligned with the incoming beam
- short falloff that does not cover neighboring tower pads
- no micro sparks, debris, or detached particles
- bitmap bloom renders behind the enemy body at no more than `54 px` and `0.64` alpha

Impact atlases use transparent bitmap frames with realistic falloff. The bitmap bloom is a backplate, while only compact tower-specific line work may render in front of the enemy. The primary light should not be a flat vector ring.

Matched effects use a concentrated cyan, green, or amber core according to tower type. Mismatched effects use a weaker red-orange scattered flash.

## Tower-Specific Signatures

### I2C

A cyan scan bracket appears close to the enemy body and contracts toward the core. The bracket lasts less than 180 ms and does not form a large field around the enemy.

### Filter

Two teal damping arcs contract toward the contact point while a soft disturbance rapidly loses amplitude. The motion communicates suppression rather than explosion.

### Peak

An amber-white core briefly overexposes, followed by a single restrained threshold pulse. This is the sharpest impact signature without using sparks.

### Low Power

A green-white clamp arc closes around the core, followed by a brief core blackout. The effect is more electrical than explosive and supports the existing stun identity.

Tower-specific signatures supplement the shared recoil and bloom. They do not add another full-screen or full-radius layer.

## Health Communication

Persistent enemy health bars are removed.

### Material Damage States

- Above 60 percent health: stable core light and normal animation.
- From 25 to 60 percent: restrained body flicker without detached fault sparks.
- Below 25 percent: amber warning core, unstable motion, and a restrained failure pulse.

These states communicate condition but do not attempt to replace precise numbers.

### Hover Health

Hovering an enemy displays one compact glass information chip with current health, maximum health, and percentage, for example `生命 68 / 120 · 57%`.

- Only one chip can be visible at a time.
- When enemies overlap, choose the closest enemy to the pointer; use greatest route progress as the tie-breaker.
- Clamp the chip to the gameplay map and keep it clear of the right HUD.
- Fade in quickly and fade out within approximately 120 ms after the pointer leaves.
- Hover does not pause gameplay or select the enemy.

Touch users retain access to exact health through diagnosis because touch has no persistent hover state.

### Diagnosis Health

The diagnosis data overlay includes current health, maximum health, and percentage. This information uses the existing right-HUD typography and does not create another gameplay-field label.

## Death Feedback

When health reaches zero:

1. Award energy and trusted data immediately.
2. Remove the enemy from targeting and wave-completion logic immediately.
3. Create a visual-only death echo lasting approximately 260 ms.
4. Stop its movement, dim the core, and lower or compress the structure without emitting fragments.
5. Fade the echo without leaving a label or health indicator behind.

Death echoes are separate from active enemies so they cannot absorb attacks, block wave completion, or delay rewards. Simultaneous deaths may coexist up to the visual effect cap.

## Rendering And State Boundaries

- Enemy dictionaries hold only short-lived body reaction values and health-state inputs.
- Impact and death visuals use dedicated transient arrays that follow the existing attack-effect pattern.
- Sprite transform is reset immediately after drawing each enemy so recoil cannot affect paths, towers, or HUD elements.
- Impact timing and tower signatures are deterministic per event to make visual tests repeatable.
- Pausing the game pauses hit and death effect timers.
- Resetting, changing levels, or returning to the menu clears every transient effect and hover target.

## Density And Performance Limits

- Maximum 24 simultaneous impact events.
- Maximum 12 simultaneous death echoes.
- New events replace the oldest completed or weakest mismatched effects when a cap is reached.
- The effect system remains custom-drawn and data-oriented; it does not create a scene node for every impact.

## Testing

Automated coverage should verify:

- matched and mismatched reactions produce different motion and light profiles
- impact events contain no micro sparks or debris
- bitmap bloom renders before enemy bodies and compact signatures render after them
- recoil changes only visual position, never route progress
- persistent health bars are absent
- hover health appears only for the current hover target and remains inside the map safe area
- diagnosis data includes exact health
- lethal damage grants rewards immediately and creates a non-targetable death echo
- resets and level changes clear all transient effects
- visual caps are enforced under simultaneous attacks

Visual QA captures should cover:

- one matched and one mismatched hit
- each of the four tower signatures
- medium and critical enemy damage states
- overlapping enemies with one hover chip
- simultaneous attacks in levels 2 and 3
- lethal hit and the final death frame

## Acceptance Criteria

- A matched hit is understandable without reading floating text.
- Mismatched attacks look visibly weaker than matched attacks.
- Enemy sprites show clear physical response without leaving their route logically.
- The battlefield has no persistent enemy health bars.
- Exact health remains available through hover and diagnosis.
- Four tower impact signatures are distinguishable at normal gameplay scale.
- Killed enemies never disappear in a single frame and never remain targetable.
- Multi-tower combat stays readable and does not cover enemy bodies, nearby tower pads, or the route.
