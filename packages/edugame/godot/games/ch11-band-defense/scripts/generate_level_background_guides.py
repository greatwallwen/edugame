from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "visual-audit"
CANVAS = (1280, 720)
MAP_WIDTH = 960

LEVELS = {
    2: {
        "route": [
            (88, 332),
            (132, 332),
            (190, 332),
            (262, 278),
            (250, 440),
            (410, 440),
            (410, 278),
            (434, 210),
            (552, 210),
            (622, 286),
            (622, 372),
            (690, 426),
            (816, 426),
            (850, 382),
            (868, 354),
        ],
        "slots": [(214, 207), (476, 142), (332, 354), (550, 405), (762, 257), (806, 487)],
    },
    3: {
        "route": [
            (88, 342),
            (124, 342),
            (178, 342),
            (256, 292),
            (256, 470),
            (454, 470),
            (454, 350),
            (506, 350),
            (578, 270),
            (656, 270),
            (712, 342),
            (712, 410),
            (792, 410),
            (843, 372),
            (868, 350),
        ],
        "slots": [(212, 227), (362, 398), (476, 240), (562, 432), (644, 212), (772, 288), (826, 472)],
    },
}


def _draw_guide(level_number: int) -> Image.Image:
    level = LEVELS[level_number]
    route = level["route"]
    slots = level["slots"]

    image = Image.new("RGB", CANVAS, (22, 24, 30))
    draw = ImageDraw.Draw(image)

    draw.rectangle((0, 0, MAP_WIDTH - 1, CANVAS[1] - 1), fill=(214, 220, 222))
    draw.rounded_rectangle((8, 16, 940, 678), radius=34, fill=(226, 230, 230), outline=(55, 116, 134), width=7)
    draw.rounded_rectangle((30, 38, 918, 656), radius=24, fill=(238, 240, 239), outline=(105, 135, 144), width=3)

    # Pink is a strict route keep-clear corridor, not a route texture reference.
    draw.line(route, fill=(246, 78, 139), width=104, joint="curve")
    draw.line(route, fill=(255, 170, 201), width=44, joint="curve")

    # Amber circles are strict tower keep-clear regions; their centers match runtime slots.
    for x, y in slots:
        draw.ellipse((x - 66, y - 66, x + 66, y + 66), fill=(247, 198, 65), outline=(111, 76, 8), width=4)
        draw.ellipse((x - 38, y - 38, x + 38, y + 38), fill=(255, 224, 128), outline=(143, 102, 20), width=3)
        draw.ellipse((x - 6, y - 6, x + 6, y + 6), fill=(250, 199, 54))

    start_y = route[0][1]
    end_y = route[-1][1]
    draw.rounded_rectangle((42, start_y - 34, 84, start_y + 34), radius=8, fill=(65, 211, 173), outline=(12, 85, 75), width=4)
    draw.rounded_rectangle((880, end_y - 34, 922, end_y + 34), radius=8, fill=(65, 211, 173), outline=(12, 85, 75), width=4)

    # Keep the HUD side visibly forbidden to prevent generated map content from crossing the split.
    draw.line((960, 0, 960, 720), fill=(238, 77, 92), width=8)
    return image


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for level_number in sorted(LEVELS):
        out = OUT_DIR / f"level{level_number}-background-layout-guide.png"
        _draw_guide(level_number).save(out)
        print(f"generated {out}")


if __name__ == "__main__":
    main()
