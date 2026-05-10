# zirizima — Backend Architecture

> Status: planning / pre-implementation
> Audience: engineering planning. Choices favor "smallest workable thing that scales 0→100k users without rewriting."

## TL;DR — what we're building

- **Postgres + PostGIS** for spatial data (toilets, reviews, neighborhoods)
- **Node.js (Fastify) + TypeScript** for the HTTP API — boring, fast, well-typed
- **Cloudflare R2** (S3-compatible) for photos
- **Redis** for nearest-toilet result cache and rate-limiting
- **Daily ETL job** pulls Seoul Open Data → upserts into our `toilets` table
- **Anonymous device-based auth** for v1; Apple/Google sign-in optional in v2
- Hosted on **Fly.io** or **Railway** for API; **Supabase** is a tempting one-stop alternative (Postgres+Auth+Storage+Edge Functions in one)

The whole MVP backend should run for **under $30/month** until traffic justifies more.

---

## Why these choices

| Decision | Why |
|---|---|
| Postgres + PostGIS | Spatial queries (`ST_DWithin`, `ST_Distance`) are first-class. The whole "nearest free toilet" query is one indexed line of SQL. |
| Node.js + Fastify + TS | Same TypeScript across iOS Swift's JSON contracts and our HTML prototype's `data.js`. Fastify is ~2x faster than Express, has schema validation built in. |
| Cloudflare R2 | S3-compatible, no egress fees. Photo bandwidth would otherwise dominate cost. |
| Redis | Nearest-toilet results within a 100 m grid cell can be cached for 60s. Cuts DB load by ~10x on hot areas (Myeongdong, Gangnam). |
| Daily ETL from Seoul Open Data | Public toilet data changes slowly (new ones added monthly). Daily cron is plenty. We do NOT proxy the open data API live — too unreliable, slow, and we want our own quality layer on top. |
| Anonymous device auth (UUID) for v1 | Foreigners won't sign up. A UUID stored in the device + nightly garbage collection of stale ones lets users post reviews without friction. |
| Fly.io / Railway | Cheap (~$5/mo each for the API + Postgres), one-region (Seoul/Tokyo) is fine for an Asia-localized app. |

### Alternative I considered: Supabase
Supabase gives us Postgres + PostGIS + Storage + Edge Functions + Auth in one console. Strong fit. The reason I did NOT pick it as the default is that Edge Functions (Deno) are a slightly less standard runtime than Node and the DX gap costs us when we want background jobs (the ETL). If you want one-vendor simplicity over flexibility, Supabase is the right call — swap freely.

---

## System diagram (text)

```
┌─────────────┐     ┌──────────────────────┐
│  iOS app    │     │  HTML prototype      │
│  (SwiftUI)  │     │  (web/PWA fallback)  │
└──────┬──────┘     └──────────┬───────────┘
       │                       │
       │   HTTPS (REST + JSON) │
       └────────┬──────────────┘
                ▼
       ┌─────────────────────┐
       │  API server         │
       │  Fastify + TS       │
       │  (Fly.io, Seoul)    │
       └──┬──────┬──────┬────┘
          │      │      │
          ▼      ▼      ▼
   ┌─────────┐ ┌──────┐ ┌────────────┐
   │ Postgres│ │Redis │ │ Cloudflare │
   │+PostGIS │ │      │ │ R2 (photos)│
   └────┬────┘ └──────┘ └────────────┘
        │
        │ daily cron (07:00 KST)
        │
   ┌────▼─────────────────────────────────┐
   │  ETL worker                          │
   │  pulls seoul-openapi.openhub.kr,     │
   │  upserts toilets, marks deleted ones │
   └──────────────────────────────────────┘
```

---

## Data sources

### Primary: Seoul Open Data (서울 열린데이터광장)
- Endpoint: `http://openapi.seoul.go.kr:8088/{KEY}/json/SearchPublicToiletPOIService/...`
- Provides: lat/lng, name, address, hours, accessible, baby-change, gender separation, manager info
- Updated monthly-ish. We pull daily but only upsert changed rows.
- License: KOGL Type 1 (commercial use OK with attribution).

### Crowdsourced (our own)
- Star rating (1–5)
- Tag set (clean / spacious / quiet / busy / english_signs / has_paper / dirty)
- Photo (optional, max 4MB, auto-resized to 1080px wide WebP)
- Anonymous device-tied review (one per device per toilet; latest wins)

### Future
- Optional integration with **Naver Place** reviews via official API (license-permitting) for hotspots that lack our own crowd data
- "Hidden gem" curated toilets (manually entered cafe/hotel/department-store toilets)

---

## Tech stack — concrete

```
runtime:       Node.js 20 LTS
http:          Fastify 4
language:      TypeScript 5
db driver:     Postgres.js (slonik or postgres) — type-safe queries
db migrations: dbmate (SQL files, no ORM ceremony)
validation:    Zod
spatial:       PostGIS 3
cache:         Redis 7 (Upstash free tier is fine for MVP)
storage:       Cloudflare R2 + AWS SDK v3 (works with R2's S3-compat API)
auth:          custom anonymous device tokens (HS256 JWT, 90-day rolling)
hosting:       Fly.io (api in nrt/icn region) + Fly Postgres
ci:            GitHub Actions → fly deploy
observability: Axiom (free tier 0.5GB/day) for logs + traces
errors:        Sentry (free tier 5k events/mo)
```

We avoid:
- ORMs (Prisma, TypeORM) — they obscure the spatial queries that matter most
- Auth as a Service (Auth0, Clerk) — overkill for anonymous-first
- Kubernetes — single-region API, single replica is plenty for v1

---

## Non-functional notes

### Latency budget
- Home screen "nearest 3" call: < 250 ms p95 from Seoul, < 500 ms from US East
- Detail page (toilet + 3 reviews): < 350 ms p95
- Search areas: < 150 ms p95 (cached)

### Rate limiting
- 60 req/min per IP for read endpoints
- 5 reviews/hour per device for write endpoints
- Photo upload: 10/hour per device, 4MB max each

### Privacy
- We never store user lat/lng. The `nearest` endpoint is stateless.
- Anonymous device tokens are random UUIDs, no PII collected.
- Photos are scanned on upload (basic content moderation via a hosted service like Hive or Sightengine — pay-as-you-go ~$0.001/image)

### Localization
- All toilet names and addresses are stored as JSONB:
  `{ en: "...", ko: "...", zh: "...", ja: "..." }`
- ETL extracts Korean from open data; English/Chinese/Japanese names are auto-generated via translation pipeline (DeepL API ~$5/mo for our volume) and tagged as `auto_translated: true`. Users can suggest improvements in v2.

---

## Phasing

### v1 (MVP — 4 weeks of backend work)
- Postgres + PostGIS + base toilets table
- Daily ETL job from Seoul Open Data
- 4 endpoints: `nearest`, `list`, `get-by-id`, `search-areas`
- No reviews yet (UI shows base data only)
- iOS app + web prototype both consume the same API

### v2 (4–6 weeks later)
- Crowdsourced reviews (rating + tags + comment + photo)
- Anonymous device-based auth
- Photo upload to R2 with content moderation
- Filter endpoint with full predicate support

### v3 (when there's traffic to justify)
- Redis caching layer for nearest queries
- Push notifications ("you reviewed this toilet — add a photo?")
- Apple/Google sign-in for users who want history across devices
- Naver Place review aggregation for hotspots
- Admin dashboard for moderating reviews/photos

---

## Cost estimate (monthly, MVP)

| Item | Cost |
|---|---|
| Fly.io API (1× shared-cpu-1x) | $1.94 |
| Fly Postgres (1× shared-cpu-1x, 10GB) | $9 |
| Upstash Redis (free tier, 10k cmd/day) | $0 |
| Cloudflare R2 (10GB storage + zero egress) | $0.15 |
| DeepL API (translation, ~5k chars/mo) | $0 |
| Axiom logs (free tier) | $0 |
| Sentry errors (free tier) | $0 |
| Domain (.com) | $1.20 amortized |
| **Total** | **~$13/mo** |

At 100k MAU we'd expect this to be ~$80–150/mo, dominated by Postgres scale-up and R2 storage. Still trivial.

---

## Things I'm not solving in this doc

- Specific HTTP routes and request/response shapes → see `API.md`
- Database schema (table definitions) → see `DATA_MODEL.md`
- iOS networking layer / SwiftData modeling → out of scope until we ship the iOS app
- CI/CD pipeline details → standard GitHub Actions → fly deploy
- Monitoring dashboards → start with Axiom default views, iterate from there
