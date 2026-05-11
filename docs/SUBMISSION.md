# App Store Submission — zirizima

This is the morning checklist. Follow top to bottom and you'll have an
app submitted for review by lunch.

## Before you start (15 min)

- [ ] **Install Xcode** from Mac App Store (~7 GB). Open once, accept license.
- [ ] **Apple Developer Program enrollment** ($99/year)
      → https://developer.apple.com/programs/enroll/
      Personal account is fine. Approval is usually instant for individuals.
- [ ] **Buy a domain** (optional but recommended for a real app)
      → e.g., zirizima.app from Cloudflare Registrar (~$14/year, no markup)
      Needed for the privacy policy URL.
- [ ] **Push key to GitHub** — see `docs/HANDOFF.md` for the SSH key setup.

## Step 1 — Verify the build runs (20 min)

```bash
cd ~/zirizima/ios
xcodegen generate
open zirizima.xcodeproj
```

In Xcode:
1. Pick your iPhone simulator from the target dropdown (top center)
2. ⌘R to run
3. Walk through onboarding → home → detail → rate. Confirm everything
   loads from the live backend.

If anything errors, the most likely culprits are SwiftUI version
quirks. Common fixes:
- `@Environment(AppState.self)` requires iOS 17+. If targeting older,
  swap to `@EnvironmentObject` and make AppState `ObservableObject`.
- `CLLocationManagerDelegate` callbacks may need `@unchecked Sendable`
  on stricter Swift 6 settings.

## Step 2 — App icon (10 min)

The Asset Catalog references `icon-1024.png` which doesn't exist yet.
Easiest path:
1. Go to https://icon.kitchen
2. Type "zirizima" or upload a 1024×1024 image
3. Download the iOS app icon set
4. Drag the `Assets.xcassets/AppIcon.appiconset/` contents into the
   placeholder slot in Xcode

## Step 3 — App Store Connect setup (30 min)

1. Go to https://appstoreconnect.apple.com → My Apps → "+" → New App
2. Fill in:
   - **Platform:** iOS
   - **Name:** zirizima (or your preferred display name)
   - **Primary Language:** English
   - **Bundle ID:** `app.zirizima` (must match `project.yml`)
   - **SKU:** `zirizima-001` (any unique string)
3. **App Information**
   - Subtitle (30 char max): "Seoul Free Toilets"
   - Category: Travel
   - Content Rights: I do not own or have licensed third-party content
4. **Pricing:** Free
5. **Availability:** All countries (or pick: South Korea + USA + Japan + China)
6. **App Privacy** (this is the important one):
   - Tap "Get Started"
   - **Location** (precise, when in use)
     - Used for: App Functionality, Third-Party Advertising
     - Linked to user: NO
     - Used for tracking: NO
   - **User Content** (rating + tags + comment)
     - Used for: App Functionality
     - Linked to user: NO
     - Used for tracking: NO
   - **Device ID** (IDFV — collected automatically by Google Mobile Ads SDK; not IDFA, ATT prompt not shown)
     - Used for: Third-Party Advertising
     - Linked to user: NO
     - Used for tracking: NO
   - **Diagnostics** (Crash Data, Performance Data — collected by Google Mobile Ads SDK)
     - Used for: App Functionality, Analytics
     - Linked to user: NO
     - Used for tracking: NO

## Step 4 — Screenshots (45 min)

App Store requires screenshots for at least one iPhone size. Take from
the iPhone 6.7" Simulator (iPhone 15 Pro Max).

1. Run the app in iPhone 15 Pro Max simulator
2. ⌘S in Simulator → screenshots saved to ~/Desktop
3. Recommended set (5 screens):
   - Splash with wordmark
   - Home with the big distance card
   - Detail page with reviews
   - List view with filter chips
   - Rate screen with stars + tags
4. Drag into App Store Connect → Screenshots section
5. Add a 1-line caption above each (optional but better)

## Step 5 — Metadata (20 min)

In App Store Connect → App Information:

- **Promotional text** (170 chars):
  > Find the nearest free public toilet in Seoul. 4,400+ locations,
  > English signage info, ratings from real travelers.

- **Description** (up to 4000 chars):
  > zirizima is the fastest way to find a free public toilet in Seoul.
  > Designed for tourists. Available in English, 中文, 日本語, 한국어.
  >
  > • Every public toilet in Seoul — 4,400+ locations from official city data
  > • Distance + walking time at a glance
  > • Filter by wheelchair access, baby changing, 24-hour, English signage
  > • Real ratings from other travelers
  > • One tap to walking directions in Google Maps
  > • Works in English, Chinese, Japanese, Korean
  >
  > No account required. Your location is never stored or shared.

- **Keywords** (100 chars, comma-separated):
  > toilet,bathroom,restroom,seoul,korea,travel,tourist,free,wc,public

- **Support URL:** https://zirizima.app/support  (or a placeholder GitHub
  page — Apple just needs *some* URL that loads)
- **Marketing URL:** (optional) https://zirizima.app
- **Privacy Policy URL:** https://zirizima.app/privacy (REQUIRED)

## Step 6 — Build + upload (15 min)

In Xcode:
1. Select target dropdown → "Any iOS Device (arm64)"
2. Product → Archive (takes ~2 min)
3. Window → Organizer opens → click your archive
4. Distribute App → App Store Connect → Upload
5. Wait for "Upload Successful" (~5 min)

The build takes 5-30 min to process on Apple's side. You'll get an email.

## Step 7 — Submit for review

In App Store Connect → your app → version 1.0:
1. Add screenshots (Step 4)
2. Add metadata (Step 5)
3. Build → select the version Xcode just uploaded
4. Export Compliance: "No, my app does not use encryption" (since we set
   `ITSAppUsesNonExemptEncryption=false` in Info.plist)
5. Submit for Review

Apple usually responds in 24-48 hours. Common rejection reasons for
travel apps:
- Privacy policy not accessible at the URL → fix the URL, resubmit
- Description mentions features the app doesn't have → trim description
- Screenshots show non-final UI → re-take

## What to do after approval

- Share the App Store URL on social, with foreigner-Korea communities
  (Reddit r/korea, expat blogs, hostels)
- Watch for crash reports in Xcode Organizer
- Watch for ratings — respond to the bad ones
- Iterate based on actual usage. The HTML prototype is a quick way to
  test new features before adding them to iOS.

Good luck!
