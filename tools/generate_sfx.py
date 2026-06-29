#!/usr/bin/env python3
"""Generate synthetic sound effects for ATB WorldCup using ffmpeg.

Run from the project root with ffmpeg installed:
    python tools/generate_sfx.py
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "assets" / "sfx"
SFX_DIR.mkdir(parents=True, exist_ok=True)


def run_ffmpeg(out_name: str, filter_graph: str, duration: float) -> None:
    """Render a mono WAV file from an ffmpeg lavfi filter graph."""
    out_path = SFX_DIR / out_name
    cmd = [
        "ffmpeg",
        "-y",
        "-f", "lavfi",
        "-i", filter_graph,
        "-t", str(duration),
        "-acodec", "pcm_s16le",
        "-ac", "1",
        "-ar", "44100",
        str(out_path),
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"saved {out_path.relative_to(ROOT)}")


def kick() -> None:
    """Short, punchy kick thud."""
    # Low sine sweep that decays quickly.
    graph = (
        "sine=frequency=120:duration=0.15,"
        "afade=t=out:st=0:curve=log:d=0.12"
    )
    run_ffmpeg("kick.wav", graph, 0.15)


def bounce() -> None:
    """Short ball-bounce click."""
    graph = (
        "sine=frequency=380:duration=0.08,"
        "afade=t=out:st=0:curve=log:d=0.08"
    )
    run_ffmpeg("bounce.wav", graph, 0.08)


def substitute() -> None:
    """Short chirp indicating a player swap."""
    graph = (
        "sine=frequency=1000:duration=0.15,"
        "afade=t=out:st=0:curve=qsin:d=0.12"
    )
    run_ffmpeg("substitute.wav", graph, 0.15)


def whistle() -> None:
    """Referee whistle."""
    # 2200Hz tone with a little vibrato, lasting ~0.5s.
    graph = (
        "sine=frequency=2200:duration=0.5,"
        "vibrato=f=8:d=0.3,"
        "afade=t=out:st=0.35:curve=qsin:d=0.15"
    )
    run_ffmpeg("whistle.wav", graph, 0.5)


def goal() -> None:
    """Crowd cheer using filtered pink noise."""
    graph = (
        "anoisesrc=color=pink:seed=42,"
        "highpass=f=200,"
        "lowpass=f=2500,"
        "afade=t=in:st=0:curve=qsin:d=0.1,"
        "afade=t=out:st=1.4:curve=log:d=0.6,"
        "volume=1.5"
    )
    run_ffmpeg("goal.wav", graph, 2.0)


def main() -> None:
    if not shutil.which("ffmpeg"):
        raise RuntimeError("ffmpeg not found. Install ffmpeg to generate SFX.")

    kick()
    bounce()
    substitute()
    whistle()
    goal()
    print("Done.")


if __name__ == "__main__":
    main()
