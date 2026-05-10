# zirizima — Data Model

Postgres 15 + PostGIS 3. All tables use UUID primary keys. Timestamps in UTC.

---

## Table: `toilets`

The canonical record for each public toilet. Most fields come from Seoul Open Data; some are crowd-derived.

```sql
CREATE TABLE toilets (
  id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  external_id     TEXT            UNIQUE NOT NULL,           -- e.g. "seoul:p_001234"

  -- Localized name (one row per toilet, multilingual via JSONB)
  name            JSONB           NOT NULL,
  -- shape: { "en": "...", "ko": "...", "zh": "...", "ja": "..." }
  address         JSONB           NOT NULL,
  -- shape: same as name

  -- Spatial
  location        geography(POINT, 4326) NOT NULL,
  district        TEXT,                                       -- "Jongno-gu"

  -- Type
  type            TEXT            NOT NULL,
  -- enum: 'subway' | 'park' | 'public' | 'tourist_info' | 'public_building' | 'cafe_friendly'

  -- Hours
  hours_open      TIME,
  hours_close     TIME,
  is_24h          BOOLEAN         NOT NULL DEFAULT FALSE,

  -- Features (from public data)
  accessible      BOOLEAN         NOT NULL DEFAULT FALSE,
  baby_change     BOOLEAN         NOT NULL DEFAULT FALSE,
  paper_provided  BOOLEAN,                                    -- nullable: unknown
  english_sign    BOOLEAN,                                    -- nullable: unknown, derived from reviews
  gender_type     TEXT            NOT NULL DEFAULT 'separate',
  -- enum: 'separate' | 'shared' | 'gender_neutral'

  -- Crowd-aggregated
  rating_avg      NUMERIC(3, 2)   NOT NULL DEFAULT 0,         -- 0.00 – 5.00
  rating_count    INTEGER         NOT NULL DEFAULT 0,
  primary_photo   TEXT,                                       -- R2 object key for top photo

  -- Provenance
  source          TEXT            NOT NULL DEFAULT 'seoul_open_data',
  -- enum: 'seoul_open_data' | 'manual' | 'crowd'
  source_synced_at TIMESTAMPTZ,
  is_verified     BOOLEAN         NOT NULL DEFAULT FALSE,     -- admin spot-checked

  created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
  deleted_at      TIMESTAMPTZ                                 -- soft delete (closed toilets)
);

-- Spatial index for ST_DWithin / ST_Distance queries
CREATE INDEX idx_toilets_location ON toilets USING GIST (location);
-- Filter-friendly partial indexes
CREATE INDEX idx_toilets_accessible ON toilets (accessible) WHERE accessible = TRUE AND deleted_at IS NULL;
CREATE INDEX idx_toilets_24h        ON toilets (is_24h)     WHERE is_24h     = TRUE AND deleted_at IS NULL;
-- Generic active filter
CREATE INDEX idx_toilets_active     ON toilets (deleted_at) WHERE deleted_at IS NULL;
```

**Why JSONB for name/address?** A single row per toilet, all 4 languages alongside. No JOIN to a `toilets_i18n` table on every read. PostgreSQL indexes specific keys via `(name->>'en')` if we ever need to.

---

## Table: `reviews`

Each anonymous device can leave one review per toilet. Resubmitting overwrites.

```sql
CREATE TABLE reviews (
  id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  toilet_id       UUID            NOT NULL REFERENCES toilets(id) ON DELETE CASCADE,
  device_id       UUID            NOT NULL,                  -- anonymous client UUID

  rating          SMALLINT        NOT NULL CHECK (rating BETWEEN 1 AND 5),
  tags            TEXT[]          NOT NULL DEFAULT '{}',
  -- allowed: 'clean' | 'dirty' | 'spacious' | 'cramped' | 'quiet' | 'busy'
  --        | 'english_signs' | 'has_paper'
  comment         TEXT            CHECK (length(comment) <= 280),
  photo_key       TEXT,                                       -- R2 object key, nullable
  language_code   TEXT,                                       -- 'en' | 'ko' | 'zh' | 'ja' (auto-detected)

  status          TEXT            NOT NULL DEFAULT 'visible',
  -- enum: 'visible' | 'hidden_by_moderation' | 'hidden_by_user' | 'pending_review'
  flagged_count   INTEGER         NOT NULL DEFAULT 0,

  created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

  UNIQUE (toilet_id, device_id)                                -- one review per device per toilet
);

CREATE INDEX idx_reviews_toilet_recent ON reviews (toilet_id, created_at DESC) WHERE status = 'visible';
CREATE INDEX idx_reviews_device        ON reviews (device_id);
```

**Aggregate update.** A trigger maintains `toilets.rating_avg` and `toilets.rating_count` whenever a review is inserted/updated/deleted:

```sql
CREATE OR REPLACE FUNCTION update_toilet_rating() RETURNS TRIGGER AS $$
BEGIN
  UPDATE toilets SET
    rating_avg = COALESCE((SELECT AVG(rating)::numeric(3,2) FROM reviews
                           WHERE toilet_id = NEW.toilet_id AND status = 'visible'), 0),
    rating_count = (SELECT COUNT(*) FROM reviews
                    WHERE toilet_id = NEW.toilet_id AND status = 'visible'),
    updated_at = now()
  WHERE id = NEW.toilet_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER reviews_after_change
AFTER INSERT OR UPDATE OR DELETE ON reviews
FOR EACH ROW EXECUTE FUNCTION update_toilet_rating();
```

---

## Table: `photos`

Photo metadata. The actual file lives in R2 under the `photo_key`.

```sql
CREATE TABLE photos (
  id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  toilet_id       UUID            NOT NULL REFERENCES toilets(id) ON DELETE CASCADE,
  review_id       UUID                       REFERENCES reviews(id) ON DELETE SET NULL,
  device_id       UUID            NOT NULL,

  storage_key     TEXT            NOT NULL UNIQUE,            -- R2 object key
  width           INTEGER,
  height          INTEGER,
  bytes           INTEGER,
  content_type    TEXT,                                       -- 'image/webp'

  moderation_status TEXT          NOT NULL DEFAULT 'pending',
  -- enum: 'pending' | 'approved' | 'rejected'
  moderation_score JSONB,                                     -- raw response from moderation provider

  created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE INDEX idx_photos_toilet ON photos (toilet_id) WHERE moderation_status = 'approved';
```

---

## Table: `areas`

Hand-curated tourist neighborhoods for "Search by area" feature.

```sql
CREATE TABLE areas (
  id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  slug            TEXT            UNIQUE NOT NULL,            -- 'myeongdong'
  name            JSONB           NOT NULL,                   -- { en, ko, zh, ja }
  centroid        geography(POINT, 4326) NOT NULL,
  radius_meters   INTEGER         NOT NULL DEFAULT 800,
  popularity      INTEGER         NOT NULL DEFAULT 0,         -- for sorting

  created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

CREATE INDEX idx_areas_centroid ON areas USING GIST (centroid);
```

Counted as `nToilets(area)` via:

```sql
SELECT COUNT(*) FROM toilets
WHERE deleted_at IS NULL
  AND ST_DWithin(location, $area_centroid, $area_radius_meters);
```

---

## Table: `devices`

Anonymous client identifiers. We don't store anything personal, but we keep this table to enable rate limiting, review history, and one-review-per-device enforcement.

```sql
CREATE TABLE devices (
  id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  platform        TEXT,                                       -- 'ios' | 'web' | 'android'
  language_code   TEXT,                                       -- last-used language
  user_agent      TEXT,                                       -- for debugging only
  first_seen_at   TIMESTAMPTZ     NOT NULL DEFAULT now(),
  last_seen_at    TIMESTAMPTZ     NOT NULL DEFAULT now(),
  banned          BOOLEAN         NOT NULL DEFAULT FALSE,
  banned_reason   TEXT
);

CREATE INDEX idx_devices_last_seen ON devices (last_seen_at);
```

**Privacy:** the `id` is a random UUID generated on first launch. No phone number, no email, no IDFA. Devices inactive for 365 days are purged nightly along with their reviews and photos.

---

## Table: `etl_runs`

Tracks daily Seoul Open Data sync. Useful for debugging.

```sql
CREATE TABLE etl_runs (
  id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  source          TEXT            NOT NULL,                   -- 'seoul_open_data'
  started_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),
  finished_at     TIMESTAMPTZ,
  status          TEXT            NOT NULL DEFAULT 'running', -- 'running' | 'success' | 'failed'
  toilets_added   INTEGER,
  toilets_updated INTEGER,
  toilets_marked_deleted INTEGER,
  error_message   TEXT
);
```

---

## Common queries

### Nearest 5 toilets

```sql
SELECT
  id, name, address, type,
  ST_Y(location::geometry) AS lat,
  ST_X(location::geometry) AS lng,
  ROUND(ST_Distance(location, ST_MakePoint($1, $2)::geography))::int AS distance_meters,
  rating_avg, rating_count,
  accessible, baby_change, is_24h, english_sign
FROM toilets
WHERE deleted_at IS NULL
  -- optional filters
  AND ($3 = FALSE OR accessible = TRUE)
  AND ($4 = FALSE OR baby_change = TRUE)
  AND ($5 = FALSE OR is_24h     = TRUE)
  AND ($6 = FALSE OR english_sign = TRUE)
ORDER BY location <-> ST_MakePoint($1, $2)::geography
LIMIT $7;
```

The `<->` operator uses the GIST index for KNN ordering. This stays fast even at 10M rows.

### Recent reviews for a toilet

```sql
SELECT id, rating, tags, comment, language_code, photo_key, created_at
FROM reviews
WHERE toilet_id = $1 AND status = 'visible'
ORDER BY created_at DESC
LIMIT $2;
```

### Upsert a review (one-per-device)

```sql
INSERT INTO reviews (toilet_id, device_id, rating, tags, comment, photo_key, language_code)
VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (toilet_id, device_id) DO UPDATE SET
  rating = EXCLUDED.rating,
  tags = EXCLUDED.tags,
  comment = EXCLUDED.comment,
  photo_key = COALESCE(EXCLUDED.photo_key, reviews.photo_key),
  language_code = EXCLUDED.language_code,
  updated_at = now()
RETURNING *;
```

---

## Sizing assumptions

| Entity | v1 estimate | 1 year | 3 years |
|---|---|---|---|
| toilets | ~5,000 | ~6,500 | ~8,000 |
| reviews | ~1,000 | ~50,000 | ~500,000 |
| photos | ~200 | ~10,000 | ~150,000 |
| devices | ~5,000 | ~80,000 | ~600,000 |

Even at 3 years out the database is well under 5GB. Fly Postgres at ~$30/mo is plenty.
