# Morning handoff — what to do first

You went to bed and asked Claude to take this to the App Store. Here's
where you are when you wake up:

## What got done overnight

| Area | Status |
|---|---|
| HTML prototype: stripped photos, added comment field | ✅ |
| Backend: reviews table + RPCs + RLS, photo path removed | ✅ |
| Prototype wired to live reviews (real Supabase) | ✅ |
| Git repo initialized at `/Users/yeom/zirizima/` | ✅ |
| **Push to github.com/jihoabba/zirizima** | ⚠️ blocked on auth — see Step 1 |
| iOS SwiftUI app fully scaffolded — 9 screens, models, networking, i18n | ✅ |
| `xcodegen generate` runs cleanly, project file written | ✅ |
| **End-to-end iOS build verified** | ⚠️ blocked — Xcode.app not installed on this Mac |
| Submission docs (`docs/SUBMISSION.md`) | ✅ |
| Privacy policy (`docs/PRIVACY.md`) — KO + EN | ✅ |

## Step 1 — Push to GitHub (60 seconds)

There are 2 commits sitting locally on `main`. The remote is set to
the SSH alias `git@github.com-zirizima:jihoabba/zirizima.git` (uses a
dedicated key I generated).

**Path A — SSH (recommended, faster long-term):**

1. Copy this public key:

   ```
   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH5K1oD0pUT1tSvwNu/rFS7tuJYyiIubCw1FEd0yunLk yumdongja@gmail.com (zirizima deploy)
   ```

   (Or run `cat ~/.ssh/zirizima_deploy.pub` to copy it.)

2. Open https://github.com/settings/ssh/new
3. Title: `zirizima deploy` (or whatever). Paste the key. Save.
4. Push:
   ```bash
   cd ~/zirizima
   git push -u origin main
   ```

**Path B — gh CLI (also fine, takes 30 seconds longer):**

```bash
cd ~/zirizima
gh auth login            # web flow — pick HTTPS, GitHub.com, browser
git remote set-url origin https://github.com/jihoabba/zirizima.git
git push -u origin main
```

If the repo `jihoabba/zirizima` doesn't exist yet on GitHub, create
it first (empty, no README) at https://github.com/new — it took the
default repo URL you gave me at face value.

## Step 2 — Install Xcode + try the iOS build (30 min)

Xcode is required to compile iOS apps. The Mac on which this code was
written only has Command Line Tools.

```bash
# Mac App Store install (free, ~7 GB)
mas install 497799835    # if you have `mas` cli
# or just open the App Store app and search "Xcode"
```

After installing, open Xcode at least once, accept the license, then:

```bash
cd ~/zirizima/ios
xcodegen generate
open zirizima.xcodeproj
```

In Xcode:
1. Select an iPhone 15 simulator from the target dropdown
2. Press ⌘R to run

**Likely first-build issues** I couldn't pre-check without Xcode:
- Maybe a SwiftUI API used here is iOS 17.1+ instead of 17.0 — bump
  the deployment target in `project.yml` and regenerate
- Maybe `LocationManager` needs `@unchecked Sendable` for Swift 6
- App icon will be a placeholder until you add a 1024×1024 PNG to
  `ios/zirizima/Assets.xcassets/AppIcon.appiconset/`

If you hit anything weird, paste the Xcode error here and I'll fix it.

## Step 3 — Continue with submission

Once the build runs in the simulator, follow `docs/SUBMISSION.md`
top to bottom. Total time from there to "Submitted for Review":
~2 hours.

## What to know about the prototype changes

- Photos completely removed (no carousel, no upload). The toilet detail
  page still has a colored gradient header — type-driven (subway = blue,
  park = green, etc.), so it doesn't look empty.
- Rate screen now has an optional one-line comment input.
- Reviews are stored in a new `reviews` table via the `submit_review`
  RPC. RLS allows anyone to read visible reviews; only the secured
  RPC can write. Rate-limited at 5 reviews/hour per device.
- Backend cost: still $0/month (Supabase free tier).

## What to know about the iOS app

- Pure SwiftUI, iOS 17+, no third-party dependencies (URLSession +
  JSONDecoder for Supabase, no SDK).
- Same 8 screens as the prototype, plus the FilterSheet. Same flow.
- `AppState` is `@Observable @MainActor` — modern Swift, no
  `@EnvironmentObject` needed.
- `Localized.swift` mirrors the JS i18n table 1:1, so renaming keys
  on either side keeps them in sync.
- Reviews / ratings hit the same Supabase RPCs as the web prototype.
  iOS uses the same anonymous device UUID approach (UserDefaults).
- Bundle ID: `app.zirizima`. Marketing version: 1.0.0.

## Caveats / things I couldn't do

1. **No iOS build verification** — only Command Line Tools installed.
   I syntax-checked all Swift files against the macOS SDK; everything
   passed except iOS-only API references (CLAuthorizationStatus etc.)
   which is expected.
2. **No GitHub push** — needed your auth, generated SSH key for you to
   add. See Step 1.
3. **No App Store screenshots** — needs the simulator running, which
   needs Xcode. See Step 4.
4. **No Apple Developer enrollment** — needs your credit card + ID.
5. **No domain purchase** — needs your credit card. Buy zirizima.app
   from Cloudflare Registrar (~$14/year) when convenient. Privacy
   policy needs a public URL eventually.

## Files added/modified overnight

```
zirizima/
├── .gitignore                  ← new
├── .git/                       ← new (git init)
├── README.md                   ← (existing, unchanged)
├── index.html                  ← (existing)
├── css/style.css               ← photo styles removed, comment field added
├── js/
│   ├── app.js                  ← photo logic removed, comment + reviews wired
│   ├── data.js                 ← real getReviews/submitRating, deviceID
│   ├── i18n.js                 ← addPhoto removed, commentPlaceholder + error strings added
│   └── icons.js                ← (existing)
├── docs/
│   ├── BACKEND.md              ← (existing)
│   ├── DATA_MODEL.md           ← (existing)
│   ├── API.md                  ← (existing)
│   ├── SUBMISSION.md           ← NEW: App Store submission step-by-step
│   ├── PRIVACY.md              ← NEW: privacy policy KO + EN
│   └── HANDOFF.md              ← NEW: this file
├── etl/
│   ├── import_seoul_toilets.py
│   ├── translate_to_english.py
│   ├── push_translations.py
│   └── bulk_post.py
└── ios/                        ← NEW: full SwiftUI app
    ├── README.md
    ├── project.yml
    ├── zirizima.xcodeproj/     ← (generated by xcodegen)
    └── zirizima/
        ├── App.swift
        ├── AppState.swift
        ├── Info.plist
        ├── Assets.xcassets/
        ├── Design/
        ├── Models/
        ├── Networking/
        ├── Location/
        ├── Resources/
        ├── Routing/
        └── Screens/
```

Sleep well, build well.
