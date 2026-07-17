from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[4] / "assets" / "games" / "ch11-band-defense"
OUT = ROOT / "backgrounds" / "band-defense-map-level1-watch-debug.png"


def install(source: Path, out: Path = OUT) -> None:
    image = Image.open(source).convert("RGB")
    resized = image.resize((1280, 720), Image.Resampling.LANCZOS)
    out.parent.mkdir(parents=True, exist_ok=True)
    resized.save(out)
    print(f"wrote {out}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--out", default=OUT, type=Path)
    args = parser.parse_args()
    install(args.source, args.out)


if __name__ == "__main__":
    main()
