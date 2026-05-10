# zirizima — iOS app

SwiftUI native app for iPhone, iOS 17+.
Mirrors the HTML prototype's UX 1:1 against the same Supabase backend.

## What's here

```
ios/
├── project.yml                  XcodeGen config (generates zirizima.xcodeproj)
└── zirizima/
    ├── App.swift                @main entry
    ├── AppState.swift           @Observable state container (i18n, location, filter)
    ├── Info.plist
    ├── Assets.xcassets/         AccentColor (Action Blue) + AppIcon placeholder
    ├── Design/
    │   ├── Colors.swift         Apple-language palette
    │   ├── Typography.swift     SF Pro tokens, tight tracking
    │   └── Components.swift     PillStyle, ZCard, ZBadge, StarsView, FilterChip, ZToggle
    ├── Models/
    │   └── Models.swift         Toilet, Area, Review, ToiletFilter, LocalizedString
    ├── Networking/
    │   ├── SupabaseAPI.swift    URLSession-based REST client (zero deps)
    │   └── DeviceID.swift       Anonymous UUID in UserDefaults
    ├── Location/
    │   └── LocationManager.swift CLLocationManager wrapper
    ├── Resources/
    │   └── Localized.swift      In-code i18n table for en/ko/zh/ja
    ├── Routing/
    │   ├── AppRouter.swift      AppRoute enum
    │   └── RootView.swift       Onboarding flow + MainTab + nav path env
    └── Screens/
        ├── SplashScreen.swift
        ├── LanguageScreen.swift
        ├── PermissionScreen.swift
        ├── HomeScreen.swift
        ├── DetailScreen.swift
        ├── ListScreen.swift
        ├── FilterSheet.swift
        ├── SearchScreen.swift
        └── RateScreen.swift
```

## How to build

This needs **full Xcode** installed (not just Command Line Tools — the
iPhone SDK is only in Xcode.app). On the test machine this code was
written, only CLT was installed, so the project has not been
end-to-end compiled yet — expect minor fixes when you first build.

### One-time setup
1. Install Xcode from the Mac App Store (~7 GB, free)
2. Open Xcode at least once and accept the license
3. Verify `xcodebuild -version` shows `Xcode 15.x` or later

### Generate + open
```bash
cd ios
xcodegen generate          # writes zirizima.xcodeproj
open zirizima.xcodeproj
```

### Run on Simulator
1. Select an iPhone 15 (or any iPhone 17+) target in Xcode
2. ⌘R (Run)

### Run on real device (for App Store screenshots)
1. Sign in with your Apple ID in Xcode → Settings → Accounts
2. Select your iPhone from the target dropdown
3. Project → Signing & Capabilities → Team = your personal team
4. ⌘R (you may need to "Trust this developer" on the iPhone)

## Backend

The app talks to the same Supabase project as the HTML prototype:
- URL: `https://strdafvajmxpcwinlzdv.supabase.co`
- Region: `ap-northeast-2` (Seoul)
- Publishable key: hardcoded in `Networking/SupabaseAPI.swift` (safe — RLS enforces read-only)

If you ever need to rotate the key or move to a new project, only
`SupabaseAPI.swift` needs editing.

## Things known to need attention before App Store

1. **App icon** — the `AppIcon.appiconset` references `icon-1024.png` which
   doesn't exist yet. Add a 1024×1024 PNG. Free tool:
   https://icon.kitchen
2. **Bundle ID** — set to `app.zirizima` in `project.yml`. Change here if
   you want a different one (e.g., `com.yourname.zirizima`). After
   editing, re-run `xcodegen generate`.
3. **Development Team** — empty in `project.yml` so Xcode lets you pick
   yours. Set it manually in Xcode under Signing & Capabilities, or fill
   the `DEVELOPMENT_TEAM` field in `project.yml` and re-generate.
4. **Privacy policy URL** — Apple requires one even for "no data
   collection" apps. See `/docs/PRIVACY.md`. You'll need to host that on
   a public URL (e.g., `zirizima.app/privacy`).

See `/docs/SUBMISSION.md` for the full step-by-step submission flow.
