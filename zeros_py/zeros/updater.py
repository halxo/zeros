"""Rolling updater: snapshot -> update -> mark pending -> confirm on good boot -> else rollback."""
import datetime, json, os, subprocess

STATE = os.environ.get("ZEROS_STATE", "/var/lib/zeros/state.json")
SNAPDIR = os.environ.get("ZEROS_SNAPDIR", "/.snapshots")


def run(cmd, dry=False):
    print("+", " ".join(cmd))
    if not dry:
        subprocess.run(cmd, check=True)


def load():
    try:
        return json.load(open(STATE))
    except (OSError, ValueError):
        return {"pending": None, "last_good": None}


def save(st):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    json.dump(st, open(STATE, "w"))


def update(dry=False):
    st = load()
    name = "pre-" + datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%S")
    run(["btrfs", "subvolume", "snapshot", "-r", "/", f"{SNAPDIR}/{name}"], dry)
    st["pending"] = name           # until boot_ok() confirms, a reboot loop triggers rollback
    if not dry:
        save(st)
    run(["emerge", "--sync"], dry)
    run(["emerge", "-uDN", "--with-bdeps=y", "@world"], dry)
    return name


def boot_ok(dry=False):
    """Called by OpenRC service late in boot (after display manager/login up)."""
    st = load()
    if st["pending"]:
        st["last_good"], st["pending"] = st["pending"], None
        if not dry:
            save(st)
    return st


def rollback(dry=False):
    st = load()
    target = st.get("pending") or st.get("last_good")
    if not target:
        raise SystemExit("no snapshot to roll back to")
    run(["btrfs", "subvolume", "snapshot", f"{SNAPDIR}/{target}", "/.rollback-root"], dry)
    run(["btrfs", "subvolume", "set-default", "/.rollback-root"], dry)
    return target


def main():
    import argparse
    ap = argparse.ArgumentParser(prog="zeros-update")
    ap.add_argument("cmd", choices=["update", "boot-ok", "rollback"])
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    print({"update": update, "boot-ok": boot_ok, "rollback": rollback}[a.cmd](a.dry_run))


if __name__ == "__main__":
    main()
