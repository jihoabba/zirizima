# ASO — App Store Optimization

Localized App Store Connect metadata for four locales.
Goal: increase organic discovery without paid spend.

## Files

- `en.md` — English (Primary)
- `ko.md` — Korean
- `ja.md` — Japanese
- `zh-Hans.md` — Simplified Chinese

Each file contains: App Name, Subtitle, Promotional Text, Keywords,
Description — with the App Store Connect char limit and the actual
char count shown next to each.

## Where to paste

App Store Connect → My Apps → zirizima → App Information

For each locale:
1. Click the locale dropdown (top right of App Information page)
2. Add the locale if not already added (ko, ja, zh-Hans)
3. Paste each field into its matching App Store Connect input

Promotional Text, Keywords, and Description can be updated **without**
resubmitting the build. App Name and Subtitle changes apply to the
**next** submitted version — they go through review.

## Strategy in one paragraph

App Store search ranks App Name highest, Subtitle second, Keywords
third. The old setup wasted the App Name on the unsearchable brand
"zirizima" alone, and shipped only English metadata — so Japanese,
Chinese, and Korean searchers found nothing. The new setup combines
brand + high-intent keywords in each App Name, fully localizes
subtitle/keywords/description per locale, and never duplicates terms
across the App Name → Subtitle → Keywords chain (Apple only indexes
each term once per locale, so duplication wastes the 100-char
keyword budget).

## What still needs doing

- [ ] Localize screenshot captions per locale (optional but increases conversion)
- [ ] Record a 15–30 sec App Preview video for the 6.5" / 6.7" slots
- [ ] After 2–4 weeks, check App Store Connect → Analytics → Search Terms to see which keywords are actually getting impressions, and rotate dead keywords out
