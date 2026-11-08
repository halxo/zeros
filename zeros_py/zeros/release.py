"""Occasional named milestones. Rolling builds are tagged by date only; names are minted on demand."""
import datetime, hashlib

NAMES = ["Nova", "Aurora", "Pulse", "Zenith", "Quark", "Ember", "Vertex", "Cipher", "Halo", "Orbit"]


def rolling_tag(now=None) -> str:
    return "rolling-" + (now or datetime.datetime.utcnow()).strftime("%Y.%m.%d-%H%M")


def milestone_name(used=()) -> str:
    """Next unused code name (deterministic order; falls back to numbered suffix)."""
    for n in NAMES:
        if n not in used:
            return n
    return f"{NAMES[len(used) % len(NAMES)]}-{len(used) // len(NAMES) + 1}"


def milestone_tag(name: str, now=None) -> str:
    return f"{name.lower()}-" + (now or datetime.datetime.utcnow()).strftime("%Y.%m.%d")


if __name__ == "__main__":
    import sys
    print(milestone_name(sys.argv[1:]))
