#!/usr/bin/env python3
"""
Put the matching "Open in app" Safari extension into an IPA (Instagram, YouTube or TikTok, found by the app's bundle id).

    python3 tools/safari-ext/add-to-ipa.py <in.ipa> [out.ipa]      # out defaults to <in>+links.ipa beside it
    python3 tools/safari-ext/add-to-ipa.py --remove <in.ipa> [out]  # takes it out again

Why it exists: a re-signed app has no Associated Domains, so iOS never hands it a tapped https://instagram.com/... (youtube.com, tiktok.com)
link -- Safari opens the website. The extension is loaded by Safari, sees the address, and sends it to the app through the app's own scheme,
where the Albrhi tweak is. Read first: docs/investigations/rocket-safari-extension.md.

What it does to the IPA, and only this:
  * copies out/<app>/AlbrhiLinks.appex (build it first: bash tools/safari-ext/build.sh) to Payload/<App>.app/PlugIns/AlbrhiLinks.appex;
  * gives it the bundle id <app id>.AlbrhiLinks and the app's own version numbers (an extension whose version differs from its app is refused
    by some installers), and its executable the ad-hoc signature `ldid -S` gives (a sideloader replaces it; TrollStore keeps it);
  * writes nothing else. A PlugIns folder that exists keeps its other extensions.
"""
import os, plistlib, shutil, subprocess, sys, tempfile, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
APPS = {  # bundle id -> directory under out/
    "com.burbn.instagram": "instagram",
    "com.google.ios.youtube": "youtube",
    "com.zhiliaoapp.musically": "tiktok",
}
NAME = "AlbrhiLinks.appex"


def main(argv):
    remove = "--remove" in argv
    args = [a for a in argv if not a.startswith("--")]
    if not args:
        raise SystemExit(__doc__)
    src = args[0]
    suffix = "-nolinks" if remove else "+links"
    dst = args[1] if len(args) > 1 else os.path.splitext(src)[0] + suffix + ".ipa"

    work = tempfile.mkdtemp(prefix="albrhi-links-")
    try:
        with zipfile.ZipFile(src) as z:
            z.extractall(work)
        payload = os.path.join(work, "Payload")
        apps = [d for d in os.listdir(payload) if d.endswith(".app")]
        if len(apps) != 1:
            raise SystemExit("expected one .app in Payload, found %r" % apps)
        app = os.path.join(payload, apps[0])
        with open(os.path.join(app, "Info.plist"), "rb") as f:
            info = plistlib.load(f)
        bundle_id = info["CFBundleIdentifier"]
        target = os.path.join(app, "PlugIns", NAME)

        if remove:
            if not os.path.isdir(target):
                raise SystemExit("this IPA has no %s" % NAME)
            shutil.rmtree(target)
            plugins = os.path.join(app, "PlugIns")
            if not os.listdir(plugins):
                os.rmdir(plugins)
        else:
            kind = APPS.get(bundle_id)
            if not kind:
                raise SystemExit("not an app this is made for: %s (Instagram, YouTube, TikTok)" % bundle_id)
            built = os.path.join(HERE, "out", kind, NAME)
            if not os.path.isdir(built):
                raise SystemExit("not built yet: run  bash tools/safari-ext/build.sh")
            os.makedirs(os.path.join(app, "PlugIns"), exist_ok=True)
            if os.path.isdir(target):
                shutil.rmtree(target)
            shutil.copytree(built, target)
            plist_path = os.path.join(target, "Info.plist")
            with open(plist_path, "rb") as f:
                ext = plistlib.load(f)
            ext["CFBundleIdentifier"] = bundle_id + ".AlbrhiLinks"
            ext["CFBundleShortVersionString"] = info.get("CFBundleShortVersionString", "1.0")
            ext["CFBundleVersion"] = info.get("CFBundleVersion", "1")
            with open(plist_path, "wb") as f:
                plistlib.dump(ext, f)
            subprocess.run(["ldid", "-S", os.path.join(target, "AlbrhiLinks")], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        if os.path.exists(dst):
            os.remove(dst)
        # Payload first, as an IPA is read; `zip -y` keeps symlinks as they are.
        subprocess.run(["zip", "-qry", os.path.abspath(dst), "Payload"], cwd=work, check=True)
        print(("removed from" if remove else "added to") + " %s (%s %s): %s" % (apps[0], bundle_id, info.get("CFBundleShortVersionString", "?"), dst))
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main(sys.argv[1:])
