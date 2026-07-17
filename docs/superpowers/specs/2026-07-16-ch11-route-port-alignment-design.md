# Ch11 Route Port Alignment Design

## Goal

Align each level's visible route and real enemy movement with the hardware ports painted into that level's map background.

## Geometry Contract

- `pathLayer.startPort` and `pathLayer.endPort` identify the map-facing outer ends of the metal contacts attached to each vertical cyan interface module.
- The first and last `path` points use those same metal-contact terminals, so route drawing and enemy movement share one anchor without covering the module body.
- The route leaves the left edge and enters the right edge horizontally before any bend.
- Enemies spawn and disappear immediately beyond the contact terminals; no light band is drawn over the vertical interface modules.
- On level 1, the lower horizontal auxiliary connectors are removed from the background and are not route anchors.

## Scope

- Measure and set independent port coordinates for levels 1, 2, and 3.
- Preserve all intermediate route controls unless a first or last horizontal lead needs a small vertical correction.
- Do not modify background images, tower slots, enemy art, tower art, or gameplay balance.

## Verification

- Regression tests lock the port centers, route edge anchors, and horizontal entrance/exit leads.
- Existing route clearance and background integrity checks continue to pass.
- Exported Web builds are inspected at all three levels for visible alignment.
