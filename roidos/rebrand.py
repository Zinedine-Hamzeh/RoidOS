#!/usr/bin/env python3
"""Turn a Husk checkout into RoidOS before it is built.

Run from the root of a Husk checkout:
    python3 /path/to/rebrand.py /path/to/icons [--repo OWNER/REPO] [--build N]

--repo   your GitHub repository (OWNER/REPO). The in-app update check looks at
         its releases, and About links to it. Without it the update check is off.
--build  a build number. The version becomes <husk version>.<N> (3.3 -> 3.3.17),
         so every build is distinguishable and the update check can compare them.

What it changes:
  * every name shown on screen, in notifications and in iOS Settings: RoidOS
  * app icon, alternate icons, in-app logo
  * bundle identifier com.roidos.app (installs beside the original)
  * sign-in to the original developer's website: removed from Settings and Home
  * links to that website: removed; game-report prompts off by default
  * update check: your repository's releases instead of the original's
  * accent colour and tab bar: RoidOS teal, Store before Library
  * no credit line

What it leaves alone, on purpose:
  * download addresses for the Android system image and gameplay pictures
    (they are large files the original project hosts; nothing on screen shows them)
  * the husk:// URL scheme (StikDebug and TrollStore use it to come back to the app)
  * code identifiers, file names and the GPL-2.0 notices in the source

Every file this script edits gets a "Modified for RoidOS" line at the top, as
the GPL asks for changed files.
"""
import argparse
import datetime
import pathlib
import re
import shutil
import sys

NAME = "RoidOS"
BUNDLE_ID = "com.roidos.app"
TAGLINE = "Android apps and games on your iPhone"
# Accent: a teal that reads on both light and dark (#0D9488), unlike the original's indigo.
ACCENT = "Color(red: 0.051, green: 0.580, blue: 0.533)"

ap = argparse.ArgumentParser()
ap.add_argument("icons", nargs="?", default="roidos/icons")
ap.add_argument("--repo", default="", help="OWNER/REPO on GitHub")
ap.add_argument("--build", default="", help="build number appended to the version")
args = ap.parse_args()

root = pathlib.Path.cwd()
app = root / "src" / "app"
icons = pathlib.Path(args.icons).resolve()
repo = args.repo.strip().strip("/")
if repo and not re.fullmatch(r"[\w.-]+/[\w.-]+", repo):
    sys.exit(f"rebrand.py: --repo must be OWNER/REPO, got {repo!r}")

if not (app / "project.yml").is_file():
    sys.exit("rebrand.py: run this from the root of a Husk checkout")

changed = set()
WORD = re.compile(r"\bHusk\b")
TODAY = datetime.date.today().isoformat()


def read(p):
    return p.read_text(encoding="utf-8")


def write(p, old, new):
    if old != new:
        p.write_text(new, encoding="utf-8")
        changed.add(p)


def must_replace(relpath, old, new, what):
    """An exact edit that the RoidOS version depends on. If the text has moved in a
    newer Husk, stop here (seconds in) rather than after the hours-long build."""
    p = app / relpath
    if not p.is_file():
        sys.exit(f"rebrand.py: {relpath} not found; Husk changed, update this script ({what})")
    t = read(p)
    if new and new in t:
        pass  # already applied (script run twice)
    elif old in t:
        write(p, t, t.replace(old, new, 1))
    elif new == "":
        pass  # already removed
    else:
        sys.exit(f"rebrand.py: could not find the text for '{what}' in {relpath}; "
                 f"Husk changed, update this script or build the last version that worked")


# ---------------------------------------------------------------- identity
p = app / "project.yml"
t = read(p)
n = re.sub(r"(HUSK_BUNDLE_IDENTIFIER:\s*)com\.husk\.app\b", rf"\g<1>{BUNDLE_ID}", t)
if n == t and f"HUSK_BUNDLE_IDENTIFIER: {BUNDLE_ID}" not in t:
    sys.exit("rebrand.py: HUSK_BUNDLE_IDENTIFIER not found in project.yml; Husk changed, update this script")
write(p, t, n)
for p in app.glob("*.xcodeproj/project.pbxproj"):   # used only if xcodegen is missing
    t = read(p)
    write(p, t, re.sub(r"\bcom\.husk\.app\b", BUNDLE_ID, t))

if args.build:
    if not re.fullmatch(r"\d+", args.build):
        sys.exit("rebrand.py: --build must be a number")
    p = app / "Husk" / "Info.plist"
    t = read(p)
    def stamp(m):
        v = m.group(2)
        return m.group(1) + (v if v.endswith("." + args.build) else v + "." + args.build) + m.group(3)
    n = re.sub(r"(<key>CFBundleShortVersionString</key>\s*<string>)(\d+(?:\.\d+)*)(</string>)", stamp, t, count=1)
    if n == t and not re.search(r"<string>\d+(?:\.\d+)*\." + args.build + "</string>", t):
        sys.exit("rebrand.py: CFBundleShortVersionString not found in Info.plist")
    write(p, t, n)

# ---------------------------------------------------------------- Settings: no account card, no site links
must_replace("Husk/SettingsTab.swift",
             '''                Section {
                    Button { Router.shared.showProfile = true } label: { accountCard }
                        .foregroundStyle(.primary)
                } footer: {
                    if !account.signedIn {
                        Text("A Husk account keeps your profile, playtime and achievements, here and on itslevii.dev.")
                    }
                }
''',
             '''                Section {
                    accountCard
                }
''', "settings account section")

must_replace("Husk/SettingsTab.swift",
             '''    /// The top of Settings, as iOS puts the Apple Account there: the Husk account (or the way to sign in), and which Husk this is.
    private var accountCard: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                if account.signedIn { AccountAvatar(size: 60) } else { HuskMark(size: 60) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(account.signedIn ? (account.user?.displayName ?? "Husk Account") : "Sign In")
                    .font(.title3.weight(.semibold))
                Text(account.signedIn ? "@" + (account.user?.username ?? "") : "Profile, playtime and achievements")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("Husk \\(Bundle.main.version) · \\(Bundle.main.commit)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
''',
             f'''    /// The top of Settings: which {NAME} this is.
    private var accountCard: some View {{
        HStack(spacing: 14) {{
            HuskMark(size: 60)
            VStack(alignment: .leading, spacing: 2) {{
                Text("{NAME}")
                    .font(.title3.weight(.semibold))
                Text("{TAGLINE}")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("Version \\(Bundle.main.version) · \\(Bundle.main.commit)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }}
            Spacer(minLength: 0)
        }}
        .padding(.vertical, 6)
    }}
''', "settings app card")

must_replace("Husk/SettingsTab.swift",
             '''                    Link(destination: CompatibilityStore.site) {
                        Label("Compatibility List", systemImage: "safari")
                    }
''', "", "compatibility website link")

must_replace("Husk/SettingsTab.swift",
             '''                    Text("Game pages and the Store show how each app runs for everyone, from itslevii.dev. Your reports go there "
                       + "with your device, iOS version, Husk build and JIT method.")''',
             f'''                    Text("Game pages and the Store show how each app runs for everyone. A report has your device, "
                       + "iOS version, {NAME} build and JIT method, and nothing else.")''', "compatibility footer")

must_replace("Husk/SettingsTab.swift",
             "@AppStorage(CompatibilityStore.askKey) private var askCompat = true",
             "@AppStorage(CompatibilityStore.askKey) private var askCompat = false", "report prompt default")
must_replace("Husk/Compatibility.swift",
             "UserDefaults.standard.object(forKey: Self.askKey) as? Bool ?? true else { return false }",
             "UserDefaults.standard.object(forKey: Self.askKey) as? Bool ?? false else { return false }",
             "report prompt default (store)")

must_replace("Husk/Compatibility.swift",
             '''            Link(destination: compat.pageURL(subject.package)) { Label("Open on itslevii.dev", systemImage: "safari") }
''', "", "game page website link")
must_replace("Husk/Compatibility.swift",
             'Text("Tested by the Husk team on an iPhone.")',
             'Text("Tested on an iPhone.")', "tested-by note")

must_replace("Husk/Compatibility.swift",
             'It shows on itslevii.dev for everyone.")',
             'It is shared with everyone.")', "report sheet footer")

must_replace("Husk/JITSetupView.swift",
             '''                point(1, "Install Husk.ipa through TrollStore, on an iOS version TrollStore supports. It carries the "
                       + "entitlements TrollStore keeps, so the same file works there and in a sideloader.",''',
             f'''                point(1, "Install {NAME}.tipa through TrollStore, on an iOS version TrollStore supports. It carries the "
                       + "entitlements TrollStore keeps.",''', "TrollStore install step")

must_replace("Husk/ProfileView.swift",
             '"Your profile, playtime and achievements, on this iPhone and on itslevii.dev."',
             '"Your profile, playtime and achievements, on this iPhone."', "profile text")

# Home: no "Sign In" in the corner menu.
must_replace("Husk/Launcher.swift",
             '''            Button { router.showProfile = true } label: {
                if let u = account.user, account.signedIn { Label(u.displayName, systemImage: "person.crop.circle") }
                else { Label("Sign In", systemImage: "person.crop.circle.badge.plus") }
            }
            Divider()
''', "", "home menu sign-in")

# About: a link to this app's own source code (the licence's condition for giving the app to others).
if repo:
    must_replace("Husk/SettingsTab.swift",
                 '''                LabeledContent("Guest image", value: GuestImage.imageVersion)
''',
                 f'''                LabeledContent("Guest image", value: GuestImage.imageVersion)
                Link("Source Code (GPL-2.0)", destination: URL(string: "https://github.com/{repo}")!)
''', "about source link")

# Update check: this app's own releases, or nothing.
must_replace("Husk/WhatsNew.swift",
             'URL(string: "https://api.github.com/repos/Leviidev/Husk/releases/latest")!',
             f'URL(string: "https://api.github.com/repos/{repo}/releases/latest")!' if repo
             else 'URL(string: "https://invalid.invalid/")!', "update check address")

# "Pair with RoidOS" in iOS Settings > Developer Mode.
must_replace("Husk/JITPairing.swift", 'static let hostName = "Husk"', f'static let hostName = "{NAME}"', "pairing name")

# ---------------------------------------------------------------- look
must_replace("Husk/AppTheme.swift",
             "static let husk = Color(red: 0.353, green: 0.322, blue: 0.945)",
             f"static let husk = {ACCENT}", "accent colour")
must_replace("Husk/AppTheme.swift",
             'Preset(id: "husk", name: "Husk", color: husk)',
             f'Preset(id: "husk", name: "{NAME}", color: husk)', "accent preset name")

must_replace("Husk/ContentView.swift",
             '''                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(HuskTab.home)

                LibraryScreen()
                    .tabItem { Label("Library", systemImage: "square.grid.2x2.fill") }
                    .tag(HuskTab.library)

                StoreView()
                    .tabItem { Label("Store", systemImage: "cart.fill") }
                    .tag(HuskTab.store)

                SettingsTab()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(HuskTab.settings)
''',
             '''                HomeView()
                    .tabItem { Label("Home", systemImage: "play.square.fill") }
                    .tag(HuskTab.home)

                StoreView()
                    .tabItem { Label("Store", systemImage: "bag.fill") }
                    .tag(HuskTab.store)

                LibraryScreen()
                    .tabItem { Label("Library", systemImage: "books.vertical.fill") }
                    .tag(HuskTab.library)

                SettingsTab()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(HuskTab.settings)
''', "tab bar")

# ---------------------------------------------------------------- every remaining name on screen
def plist_strings(t):
    def fix(m):
        v = m.group(1)
        if "$(" in v or "://" in v:
            return m.group(0)
        return "<string>" + WORD.sub(NAME, v) + "</string>"
    return re.sub(r"<string>([^<]*)</string>", fix, t)

for p in app.rglob("Info.plist"):
    if ".xcodeproj" in p.parts:
        continue
    t = read(p)
    write(p, t, plist_strings(t))

LIT = re.compile(r'"(?:[^"\\\n]|\\.)*"')
SKIP_LINE = re.compile(
    r'User-Agent|hasPrefix\(|hasSuffix\(|contains\(|forResource|named:|'
    r'subsystem:|DispatchQueue\(label:|URL\(string:|Preset\(id:'
)


def swift_fix(line):
    s = line.lstrip()
    if s.startswith("//") or "Husk" not in line or SKIP_LINE.search(line):
        return line

    def fix(m):
        lit = m.group(0)
        if "://" in lit or "/Husk" in lit or "Husk/" in lit or re.search(r"Husk\.(ipa|tipa|app|zip)", lit):
            return lit
        return WORD.sub(NAME, lit)
    return LIT.sub(fix, line)


for p in app.rglob("*.swift"):
    if ".xcodeproj" in p.parts:
        continue
    t = read(p)
    write(p, t, "".join(swift_fix(l) for l in t.splitlines(keepends=True)))

for p in app.rglob("*.strings"):   # keys are the English strings, so both sides change
    t = read(p)
    write(p, t, "\n".join(l if "://" in l else WORD.sub(NAME, l) for l in t.split("\n")))

# ---------------------------------------------------------------- icons
ICON_MAP = {
    "Husk/Assets.xcassets/AppIcon.appiconset/Icon-Default.png": "1024-default.png",
    "Husk/Assets.xcassets/AppIcon.appiconset/Icon-Dark.png": "1024-dark.png",
    "Husk/Assets.xcassets/AppIcon.appiconset/Icon-Tinted.png": "1024-tinted.png",
    "Husk/Assets.xcassets/AppIconClearLight.appiconset/Icon-1024.png": "1024-clearlight.png",
    "Husk/Assets.xcassets/AppIconClearDark.appiconset/Icon-1024.png": "1024-cleardark.png",
    "Husk/Assets.xcassets/AppIconTintedLight.appiconset/Icon-1024.png": "1024-tintedlight.png",
    "Husk/Assets.xcassets/AppIconTintedDark.appiconset/Icon-1024.png": "1024-tinteddark.png",
    "Husk/Resources/icon-default.png": "256-default.png",
    "Husk/Resources/icon-dark.png": "256-dark.png",
    "Husk/Resources/icon-clearlight.png": "256-clearlight.png",
    "Husk/Resources/icon-cleardark.png": "256-cleardark.png",
    "Husk/Resources/icon-tintedlight.png": "256-tintedlight.png",
    "Husk/Resources/icon-tinteddark.png": "256-tinteddark.png",
}
for dest, src in ICON_MAP.items():
    s, d = icons / src, app / dest
    if not s.is_file():
        have = sorted(x.name for x in icons.glob("*.png")) if icons.is_dir() else []
        sys.exit(f"rebrand.py: missing icon {src} in {icons} (found: {', '.join(have) or 'nothing'}). "
                 "All 13 PNGs from roidos-icons.zip must be in roidos/icons/.")
    if not d.parent.is_dir():
        sys.exit(f"rebrand.py: {d.parent} not found; Husk changed its icons, update this script")
    shutil.copyfile(s, d)
    changed.add(d)

# ---------------------------------------------------------------- change notices (GPL 2a)
NOTE = f"// Modified for {NAME}, {TODAY}: name, icon, identifiers and screens changed by roidos/rebrand.py.\n"
for p in changed:
    if p.suffix != ".swift":
        continue
    t = read(p)
    if "Modified for RoidOS" in t:
        continue
    lines = t.splitlines(keepends=True)
    at = 1 if lines and lines[0].startswith("// SPDX-License-Identifier") else 0
    lines.insert(at, NOTE)
    p.write_text("".join(lines), encoding="utf-8")

print(f"rebrand.py: {NAME} ({BUNDLE_ID}) applied to {len(changed)} files"
      + (f", updates from {repo}" if repo else ", update check off")
      + (f", build {args.build}" if args.build else ""))
