/* =========================================================================
   zirizima — data layer (live Supabase)
   - Hits the real Supabase REST/RPC API for toilets and areas
   - api.* signatures unchanged from the mock version, so screens.js needs
     no edits when swapping mock ↔ real
   - Reviews/ratings still stubbed (v2 work)

   Schema and RPC live in the Supabase project `zirizima` (region:
   ap-northeast-2). The publishable key is safe to ship in client code —
   RLS enforces public read-only access on the `toilets` and `areas` tables.
   ========================================================================= */

(function (window) {
  'use strict';

  // -------------------------------------------------------------------
  // Supabase config — public values, safe to expose in client
  // -------------------------------------------------------------------
  const SUPABASE_URL = 'https://strdafvajmxpcwinlzdv.supabase.co';
  const SUPABASE_KEY = 'sb_publishable_GnyAhOMQohjiXl3gTeESPQ_gFkqo1Jo';

  // Default location: Gyeongbokgung area (used until geolocation grants)
  const USER_LOCATION = { lat: 37.5759, lng: 126.9737 };

  // Anonymous device id, generated once and persisted in localStorage.
  // Used to enforce one-review-per-device and rate limiting.
  function getDeviceId() {
    const KEY = 'zirizima_device_id';
    try {
      let id = window.localStorage.getItem(KEY);
      if (!id) {
        id = (window.crypto && window.crypto.randomUUID)
          ? window.crypto.randomUUID()
          : 'dev-' + Math.random().toString(36).slice(2) + '-' + Date.now().toString(36);
        window.localStorage.setItem(KEY, id);
      }
      return id;
    } catch (_) {
      // localStorage may be blocked (e.g., private mode in some browsers).
      // Fall back to a session-only UUID — reviews still work, just not
      // edit-able after reload.
      if (!window._tempDeviceId) {
        window._tempDeviceId = (window.crypto && window.crypto.randomUUID)
          ? window.crypto.randomUUID()
          : 'tmp-' + Math.random().toString(36).slice(2);
      }
      return window._tempDeviceId;
    }
  }

  // -------------------------------------------------------------------
  // Distance / direction helpers (client-side)
  // -------------------------------------------------------------------
  function distanceMeters(lat1, lng1, lat2, lng2) {
    const R = 6371000;
    const toRad = (d) => d * Math.PI / 180;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a = Math.sin(dLat / 2) ** 2 +
              Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
              Math.sin(dLng / 2) ** 2;
    return Math.round(2 * R * Math.asin(Math.sqrt(a)));
  }

  function walkMinutes(meters) {
    return Math.max(1, Math.round(meters / 80));
  }

  function compassDirection(fromLat, fromLng, toLat, toLng) {
    const dLat = toLat - fromLat;
    const dLng = toLng - fromLng;
    const angle = Math.atan2(dLng, dLat) * 180 / Math.PI;
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW', 'N'];
    return dirs[Math.round(((angle + 360) % 360) / 45)];
  }

  // -------------------------------------------------------------------
  // Supabase fetch wrapper
  // -------------------------------------------------------------------
  async function sb(path, init = {}) {
    const r = await fetch(`${SUPABASE_URL}${path}`, {
      ...init,
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json',
        ...(init.headers || {})
      }
    });
    if (!r.ok) {
      const body = await r.text();
      throw new Error(`Supabase ${r.status} ${path}: ${body}`);
    }
    return r.json();
  }

  // -------------------------------------------------------------------
  // Transform DB row → frontend toilet shape (the prototype's existing shape)
  // -------------------------------------------------------------------
  function transformToilet(row, originLat, originLng) {
    const lat = row.lat;
    const lng = row.lng;
    const meters = (row.distance_meters != null)
      ? row.distance_meters
      : distanceMeters(originLat, originLng, lat, lng);
    return {
      id: row.id,
      externalId: row.external_id,
      name: row.name,           // already JSONB { en, ko, zh, ja }
      address: row.address,
      lat,
      lng,
      district: row.district,
      type: row.type,
      hours: {
        open: row.hours_open,
        close: row.hours_close,
        is24h: row.is_24h
      },
      accessible: row.accessible,
      babyChange: row.baby_change,
      paper: row.paper_provided,
      englishSign: row.english_sign,
      rating: parseFloat(row.rating_avg),
      reviewCount: row.rating_count,
      distanceMeters: meters,
      walkMinutes: walkMinutes(meters),
      direction: compassDirection(originLat, originLng, lat, lng)
    };
  }

  // -------------------------------------------------------------------
  // API — same signatures as the mock version
  // -------------------------------------------------------------------
  const api = {
    async getNearestToilets(lat, lng, limit = 5, filter = {}) {
      const rows = await sb('/rest/v1/rpc/nearest_toilets', {
        method: 'POST',
        body: JSON.stringify({
          in_lat: lat,
          in_lng: lng,
          in_limit: limit,
          in_accessible: !!filter.accessible,
          in_baby_change: !!filter.babyChange,
          in_open_24h: !!filter.open24h,
          in_english_sign: !!filter.englishSign
        })
      });
      return rows.map((r) => transformToilet(r, lat, lng));
    },

    async getAllToilets(lat, lng, filter = {}) {
      return this.getNearestToilets(lat, lng, 50, filter);
    },

    async getToiletById(id, lat, lng) {
      // Fetch the 50 nearest and find — saves an extra round trip
      // since the home screen has likely just called getNearestToilets.
      // For production with thousands of toilets, replace with a dedicated
      // get_toilet_by_id(id, lat, lng) RPC.
      const all = await this.getAllToilets(lat, lng);
      return all.find((t) => t.id === id) || null;
    },

    async getReviews(toiletId, limit = 5) {
      const rows = await sb('/rest/v1/rpc/get_reviews_for_toilet', {
        method: 'POST',
        body: JSON.stringify({ in_toilet_id: toiletId, in_limit: limit })
      });
      // Adapt to the shape app.js expects (author, rating, comment, tags, daysAgo)
      return rows.map((r) => {
        const days = Math.max(0, Math.round((Date.now() - new Date(r.created_at).getTime()) / 86400000));
        return {
          id: r.id,
          rating: r.rating,
          tags: r.tags,
          comment: r.comment || '',
          languageCode: r.language_code,
          createdAt: r.created_at,
          daysAgo: days,
          author: 'Anonymous'
        };
      });
    },

    async searchAreas(query) {
      // PostGIS geography columns serialize as WKB hex — annoying to parse
      // client-side. We keep a small slug→latlng map for the 8 curated areas
      // (these are hand-picked tourist hotspots, low churn).
      const SLUG_LATLNG = {
        myeongdong:    { lat: 37.5636, lng: 126.9826 },
        gangnam:       { lat: 37.4979, lng: 127.0276 },
        hongdae:       { lat: 37.5567, lng: 126.9237 },
        insadong:      { lat: 37.5740, lng: 126.9851 },
        itaewon:       { lat: 37.5347, lng: 126.9947 },
        dongdaemun:    { lat: 37.5666, lng: 127.0090 },
        gyeongbokgung: { lat: 37.5796, lng: 126.9770 },
        namdaemun:     { lat: 37.5599, lng: 126.9774 }
      };

      const rows = await sb('/rest/v1/areas?order=popularity.desc&select=id,slug,name,toilet_count');

      let areas = rows.map((a) => {
        const ll = SLUG_LATLNG[a.slug] || { lat: 37.5636, lng: 126.9826 };
        return {
          id: a.slug,            // use slug as id so existing routes keep working
          slug: a.slug,
          name: a.name,
          lat: ll.lat,
          lng: ll.lng,
          count: a.toilet_count
        };
      });

      if (query) {
        const q = query.toLowerCase();
        areas = areas.filter((a) =>
          Object.values(a.name).some((n) => String(n).toLowerCase().includes(q))
        );
      }
      return areas;
    },

    async submitRating(toiletId, rating, tags, comment) {
      const result = await sb('/rest/v1/rpc/submit_review', {
        method: 'POST',
        body: JSON.stringify({
          in_toilet_id:     toiletId,
          in_device_id:     getDeviceId(),
          in_rating:        rating,
          in_tags:          tags || [],
          in_comment:       comment || null,
          in_language_code: window.zirizimaI18n ? window.zirizimaI18n.current : 'en'
        })
      });
      return { ok: true, reviewId: result && result.review_id, isNew: result && result.is_new };
    },

    async filterCount(lat, lng, filter) {
      // For free tier we just call list and count. For production, add a
      // dedicated count RPC to avoid pulling rows.
      const list = await this.getNearestToilets(lat, lng, 50, filter);
      return list.length;
    }
  };

  // -------------------------------------------------------------------
  // Backwards-compat: AREAS array shape kept for any code that still touches it
  // -------------------------------------------------------------------
  const AREAS = [
    { id: 'myeongdong',    slug: 'myeongdong',    name: { en: 'Myeongdong',       ko: '명동',       zh: '明洞',       ja: '明洞' },       lat: 37.5636, lng: 126.9826, count: 112 },
    { id: 'gangnam',       slug: 'gangnam',       name: { en: 'Gangnam Stn.',     ko: '강남역',     zh: '江南站',     ja: '江南駅' },     lat: 37.4979, lng: 127.0276, count: 87 },
    { id: 'hongdae',       slug: 'hongdae',       name: { en: 'Hongdae',          ko: '홍대',       zh: '弘大',       ja: '弘大' },       lat: 37.5567, lng: 126.9237, count: 94 },
    { id: 'insadong',      slug: 'insadong',      name: { en: 'Insadong',         ko: '인사동',     zh: '仁寺洞',     ja: '仁寺洞' },     lat: 37.5740, lng: 126.9851, count: 68 },
    { id: 'itaewon',       slug: 'itaewon',       name: { en: 'Itaewon',          ko: '이태원',     zh: '梨泰院',     ja: '梨泰院' },     lat: 37.5347, lng: 126.9947, count: 56 },
    { id: 'dongdaemun',    slug: 'dongdaemun',    name: { en: 'Dongdaemun',       ko: '동대문',     zh: '东大门',     ja: '東大門' },     lat: 37.5666, lng: 127.0090, count: 73 },
    { id: 'gyeongbokgung', slug: 'gyeongbokgung', name: { en: 'Gyeongbokgung',    ko: '경복궁',     zh: '景福宫',     ja: '景福宮' },     lat: 37.5796, lng: 126.9770, count: 45 },
    { id: 'namdaemun',     slug: 'namdaemun',     name: { en: 'Namdaemun Market', ko: '남대문시장', zh: '南大门市场', ja: '南大門市場' }, lat: 37.5599, lng: 126.9774, count: 38 }
  ];

  // -------------------------------------------------------------------
  // Export
  // -------------------------------------------------------------------
  window.zirizimaData = {
    USER_LOCATION,
    AREAS,
    api,
    helpers: { distanceMeters, walkMinutes, compassDirection }
  };
})(window);
