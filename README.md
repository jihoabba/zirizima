# zirizima

**Seoul Free Toilets** — a complete map of every free public toilet in Seoul, in your language. Designed for the moment you need it most.

## What's in this folder

```
zirizima/
├── index.html              app shell (open this in a browser)
├── css/style.css           Apple-language design system + screens
├── js/
│   ├── data.js             mock toilet data + API stub functions
│   ├── i18n.js             EN / 中文 / 日本語 / 한국어 strings
│   ├── icons.js            inline SVG icons
│   └── app.js              router, state, screen renderers, interactions
└── docs/
    ├── BACKEND.md          backend architecture & tech choices
    ├── DATA_MODEL.md       database schema
    └── API.md              REST endpoint spec
```

## Run the prototype

Just open `index.html` in any modern browser. No build, no dependencies.

```bash
# either
open index.html

# or run a tiny local server (recommended for cleaner asset loading)
python3 -m http.server 8080
# then visit http://localhost:8080
```

## What works

- 8 connected screens with iOS-style page transitions and tap animations
- 4 language switching (EN / 中 / 日 / 한)
- Mock data for ~12 toilets near Gyeongbokgung area
- Working filter toggles, search input, star rating, tag selection
- Hash-based routing — every screen is a permalink (`#home`, `#detail/t_001`, etc.)
- "Take me there" hands off to Google Maps with walking directions
  (universal URL: opens Google Maps app on mobile, browser tab on desktop)
- Single Apple Action Blue accent throughout, parchment/canvas surface alternation

## What's mocked (= where to plug real data)

`js/data.js` is the swap point. Every read is wrapped in an async-style stub:

```js
api.getNearestToilets(lat, lng, limit)   // → list of toilets
api.getToiletById(id)                    // → toilet detail + reviews
api.searchAreas(query)                   // → matching neighborhoods
api.submitRating(id, rating, tags, photo) // → POST review
```

Each stub today returns mock data immediately. Replace the body with a real `fetch()` and the UI doesn't need to change.

## Long-term plan

This HTML prototype is for **UX validation**. The shipping product is **iOS native** (Swift + SwiftUI), reusing this design language verbatim. The backend (see `docs/BACKEND.md`) is built once and serves both web and iOS.

## Design language

Borrowed wholesale from Apple's web property — same Action Blue (`#0066cc`), parchment (`#f5f5f7`), Near-Black ink (`#1d1d1f`), pill CTAs, single drop-shadow on photos only, no gradients. Wordmark-only branding (no logo).
