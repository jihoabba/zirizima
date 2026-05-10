# zirizima — API Spec

REST + JSON. All responses include `Cache-Control` and `ETag` headers where appropriate.
Base URL: `https://api.zirizima.app/v1`

Headers on every request:
- `X-Device-Id: <uuid>` — anonymous device identifier (required for write endpoints; optional but encouraged for reads to enable per-device caching)
- `Accept-Language: en | ko | zh | ja` — server uses this to pick the right `name`/`address` string from the JSONB
- `Authorization: Bearer <jwt>` — only for v2 sign-in

---

## Error envelope

All non-2xx responses follow this shape:

```json
{
  "error": {
    "code": "TOILET_NOT_FOUND",
    "message": "Toilet does not exist or has been removed.",
    "request_id": "req_8f7a2b"
  }
}
```

Status codes:
- `400` invalid input (Zod validation failure → first error in `message`)
- `401` missing/invalid auth
- `403` rate-limited or banned
- `404` not found
- `429` too many requests
- `500` server error

---

## Endpoints

### `GET /toilets/nearest`

Used by the **Home** screen — returns the single nearest toilet plus a few alternatives.

**Query params:**
| param | type | required | default | notes |
|---|---|---|---|---|
| `lat` | float | yes | — | -90 to 90 |
| `lng` | float | yes | — | -180 to 180 |
| `limit` | int | no | 3 | max 10 |
| `accessible` | bool | no | false | filter |
| `baby_change` | bool | no | false | filter |
| `open_24h` | bool | no | false | filter |
| `english_sign` | bool | no | false | filter |

**200 OK:**
```json
{
  "toilets": [
    {
      "id": "01H8K2J9...",
      "name": "Gyeongbokgung Stn. Exit 2",
      "address": "161 Sajik-ro, Jongno-gu, Seoul",
      "type": "subway",
      "lat": 37.5759,
      "lng": 126.9737,
      "distance_meters": 156,
      "walk_minutes": 2,
      "direction": "NW",
      "hours": { "open": "05:30", "close": "24:00", "is_24h": false },
      "features": {
        "accessible": true,
        "baby_change": true,
        "paper_provided": true,
        "english_sign": true,
        "gender_type": "separate"
      },
      "rating": { "avg": 4.3, "count": 23 },
      "primary_photo_url": "https://photos.zirizima.app/abc123.webp"
    }
  ]
}
```

**Cache:** `Cache-Control: public, max-age=60`. Server sends rounded lat/lng (3 decimals = ~110 m grid) in the response Vary key, so two clients in the same block share a cache entry.

---

### `GET /toilets/list`

Used by the **List view** screen. Same filters as `nearest`, but no limit (server caps at 100).

```
GET /toilets/list?lat=37.5759&lng=126.9737&accessible=true&open_24h=true
```

Returns the same `Toilet` shape as `nearest`, sorted by distance ascending.

---

### `GET /toilets/:id`

Used by the **Detail** screen. Includes the most recent reviews inline.

**Path params:**
- `id` — UUID

**Query params:**
- `lat`, `lng` (optional) — if provided, response includes `distance_meters` and `walk_minutes`
- `review_limit` (default 3, max 20)

**200 OK:**
```json
{
  "toilet": { /* same shape as in nearest, plus full address */ },
  "photos": [
    { "url": "https://photos.zirizima.app/abc.webp", "width": 1080, "height": 1440 }
  ],
  "reviews": [
    {
      "id": "01H8...",
      "rating": 5,
      "tags": ["clean", "english_signs"],
      "comment": "Super clean and easy to find — exit 2 is right by the entrance.",
      "language_code": "en",
      "author_label": "Sarah · USA",
      "created_at": "2026-05-08T11:23:00Z"
    }
  ]
}
```

`author_label` is server-generated (never the user's chosen handle — just `Anonymous · {country guessed from IP at submit time}` or `Anonymous` if guessing fails).

---

### `POST /toilets/:id/reviews`

Submit or update a rating + tags + optional comment + optional photo.

**Body:**
```json
{
  "rating": 4,
  "tags": ["clean", "has_paper"],
  "comment": "Always clean. Sometimes a queue.",
  "language_code": "en"
}
```

**With photo upload:** the client first calls `POST /uploads/photo-url` to get a signed PUT URL, uploads to R2 directly, then sends `photo_key` in the review body:
```json
{
  "rating": 4,
  "tags": ["clean"],
  "photo_key": "uploads/2026/05/abc123.webp"
}
```

**201 Created:**
```json
{ "review": { /* full review object */ } }
```

**Errors:**
- `429` if device exceeds 5 reviews/hour
- `400` if rating is outside 1–5 or tags contain unknown values

---

### `POST /uploads/photo-url`

Get a presigned R2 upload URL. The actual photo upload goes directly from the client to R2, never through our API.

**Request:**
```json
{ "content_type": "image/webp", "byte_size": 250000 }
```

**200 OK:**
```json
{
  "photo_key": "uploads/2026/05/01H8K3...webp",
  "upload_url": "https://r2.cloudflarestorage.com/...",
  "method": "PUT",
  "expires_at": "2026-05-10T12:00:00Z",
  "max_bytes": 4194304
}
```

Client then `PUT`s the image bytes to `upload_url` with the matching `Content-Type` header. After success, the client includes `photo_key` in the review submission.

---

### `GET /areas`

For the **Search by area** screen. Returns the curated list of tourist neighborhoods.

**Query params:**
- `q` (optional) — substring search across all 4 language names

**200 OK:**
```json
{
  "areas": [
    {
      "id": "01H8...",
      "slug": "myeongdong",
      "name": "Myeongdong",
      "centroid": { "lat": 37.5636, "lng": 126.9826 },
      "toilet_count": 112
    }
  ]
}
```

`toilet_count` is materialized — refreshed nightly when ETL runs.

---

### `GET /toilets/count`

Returns just the count of toilets matching a filter set. Used to populate the "Show 14 toilets" button label in the filter sheet without fetching the full list.

**Query params:** same as `nearest` but no `limit`.

**200 OK:**
```json
{ "count": 14 }
```

Cache: 5 minutes.

---

## Endpoints we DON'T expose

- No `POST /toilets` — toilets are added via ETL or admin UI only. Crowd contributions happen via reviews, not new toilet entries (v1).
- No `DELETE /reviews/:id` — users can submit a new review which overwrites their old one. To truly delete, we have a soft-delete by setting `status = 'hidden_by_user'`.
- No `GET /reviews/:id` — reviews are always returned in the context of their toilet.

---

## Future endpoints (v2+)

- `POST /auth/sign-in` — Apple/Google sign-in for users who want sync
- `GET /me/reviews` — list of reviews this device (or signed-in user) has left
- `GET /me/saved` — saved toilets
- `POST /toilets/:id/report` — flag a toilet as closed/missing
- `GET /toilets/search` — full-text search by name (uses Postgres `tsvector`)

---

## How the prototype maps to this API

`js/data.js` in the HTML prototype defines `api.*` async functions whose names and signatures map directly to the endpoints above:

| Prototype `api.*` | API endpoint |
|---|---|
| `getNearestToilets(lat, lng, limit, filter)` | `GET /toilets/nearest` |
| `getAllToilets(lat, lng, filter)` | `GET /toilets/list` |
| `getToiletById(id, lat, lng)` | `GET /toilets/:id` |
| `getReviews(toiletId, limit)` | (inline in `GET /toilets/:id`) |
| `searchAreas(query)` | `GET /areas?q=` |
| `submitRating(id, rating, tags, photo)` | `POST /toilets/:id/reviews` (+ photo upload flow) |
| `filterCount(lat, lng, filter)` | `GET /toilets/count` |

Replacing each prototype function body with a single `fetch()` call is the entire client-side change required to ship the web/PWA against the real backend.
