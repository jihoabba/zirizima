#!/usr/bin/env python3
"""
zirizima ETL — Seoul Open Data public toilets JSON → Supabase

Input:  /Users/yeom/Downloads/서울시 공중화장실 위치정보.json
Output: SQL chunk files in /tmp/zirizima-import/chunk_NNN.sql

Usage:
    python3 import_seoul_toilets.py [INPUT_JSON] [OUTPUT_DIR] [ROWS_PER_CHUNK]

Each chunk is one INSERT ... VALUES statement that can be sent to
Supabase via the MCP execute_sql tool. Conflicts on external_id are
resolved with UPDATE (so re-running the import is idempotent).
"""

import json
import re
import sys
import os
from pathlib import Path

INPUT = sys.argv[1] if len(sys.argv) > 1 else '/Users/yeom/Downloads/서울시 공중화장실 위치정보.json'
OUTDIR = sys.argv[2] if len(sys.argv) > 2 else '/tmp/zirizima-import'
CHUNK = int(sys.argv[3]) if len(sys.argv) > 3 else 250

Path(OUTDIR).mkdir(parents=True, exist_ok=True)

# -------------------------------------------------------------------------
# Field transformations
# -------------------------------------------------------------------------

def sql_escape(value):
    """Escape a string for safe inclusion in a single-quoted SQL literal."""
    if value is None:
        return 'NULL'
    s = str(value)
    return "'" + s.replace("'", "''") + "'"


def jsonb_lit(obj):
    """Render a Python dict as a Postgres JSONB literal."""
    s = json.dumps(obj, ensure_ascii=False)
    return sql_escape(s) + '::jsonb'


def parse_hours(raw):
    """Parse a 개방시간 string like '기타|05:00~23:00|' or '24시간|'.
    Returns (hours_open, hours_close, is_24h)."""
    if not raw or not raw.strip():
        return None, None, False
    text = raw.strip().replace('|', ' ').strip()
    if '24시간' in text or '상시' in text:
        return None, None, True
    m = re.search(r'(\d{1,2}):(\d{2})\s*[~\-]\s*(\d{1,2}):(\d{2})', text)
    if m:
        oh, om, ch, cm = m.groups()
        # Normalize 24:00 → 23:59 for storage as TIME
        ch_int = int(ch)
        if ch_int >= 24:
            return f'{int(oh):02d}:{int(om):02d}', '23:59', False
        return f'{int(oh):02d}:{int(om):02d}', f'{ch_int:02d}:{int(cm):02d}', False
    return None, None, False


def detect_type(name, sojae):
    """Map building name + 소재지 → our toilet type enum."""
    n = (name or '') + ' ' + (sojae or '')
    if any(k in n for k in ['지하철역', '지하철 역', '지하철', '역사', '환승센터']):
        return 'subway'
    if re.search(r'\b\S*역\b', name or ''):
        return 'subway'
    if any(k in n for k in ['공원', '쉼터']):
        return 'park'
    if any(k in n for k in ['관광안내', '관광센터', '인포메이션', '안내소']):
        return 'tourist_info'
    if any(k in n for k in ['구청', '주민센터', '동사무소', '시청', '도서관', '박물관', '문화원', '문화회관', '복지관', '체육관', '경기장', '청사']):
        return 'public_building'
    return 'public'


def parse_accessible(raw):
    """장애인화장실 현황 — non-empty/non-whitespace means yes."""
    if not raw:
        return False
    s = str(raw).strip().replace('|', '').strip()
    return bool(s)


def parse_baby_change(raw):
    """편의시설 (기타설비) — look for 기저귀 / 영유아 / 베이비."""
    if not raw:
        return False
    s = str(raw)
    return any(k in s for k in ['기저귀', '영유아', '베이비', '유아거치대'])


def is_valid_coord(lat, lng):
    """Sanity check: must be within Seoul-ish bounds."""
    if lat is None or lng is None:
        return False
    try:
        lat = float(lat)
        lng = float(lng)
    except (TypeError, ValueError):
        return False
    return 37.40 < lat < 37.72 and 126.75 < lng < 127.20


# -------------------------------------------------------------------------
# Load + transform
# -------------------------------------------------------------------------

with open(INPUT, encoding='utf-8') as f:
    payload = json.load(f)

rows = payload['DATA']
print(f'Loaded {len(rows)} rows from {INPUT}', file=sys.stderr)

records = []
skipped_invalid = 0

for raw in rows:
    lat = raw.get('coord_y')
    lng = raw.get('coord_x')
    if not is_valid_coord(lat, lng):
        skipped_invalid += 1
        continue

    name_ko = (raw.get('conts_name') or '').strip() or '공중화장실'
    addr_road = (raw.get('addr_new') or '').strip()
    addr_lot = (raw.get('addr_old') or '').strip()
    addr_ko = addr_road or addr_lot or ''

    open_h, close_h, is_24h = parse_hours(raw.get('value_02'))
    accessible = parse_accessible(raw.get('value_05'))
    baby_change = parse_baby_change(raw.get('value_06'))
    ttype = detect_type(name_ko, raw.get('value_08'))
    district = (raw.get('gu_name') or '').strip() or None

    # Multilingual name/address: only Korean populated. The frontend's i18n.name()
    # falls back to first available value, so EN/中/日 users will see Korean for
    # now. v2 will run a translation pass.
    name = {'ko': name_ko}
    address = {'ko': addr_ko} if addr_ko else {'ko': name_ko}

    records.append({
        'external_id': f'seoul:{raw["objectid"]}',
        'name': name,
        'address': address,
        'lat': float(lat),
        'lng': float(lng),
        'district': district,
        'type': ttype,
        'hours_open': open_h,
        'hours_close': close_h,
        'is_24h': is_24h,
        'accessible': accessible,
        'baby_change': baby_change,
    })

print(f'Transformed {len(records)} valid records ({skipped_invalid} skipped for bad coords)', file=sys.stderr)

# -------------------------------------------------------------------------
# Write SQL chunks
# -------------------------------------------------------------------------

def row_to_values(r):
    """Build the VALUES tuple for one record."""
    return (
        '('
        f'{sql_escape(r["external_id"])}, '
        f'{jsonb_lit(r["name"])}, '
        f'{jsonb_lit(r["address"])}, '
        f'ST_MakePoint({r["lng"]}, {r["lat"]})::geography, '
        f'{sql_escape(r["district"])}, '
        f'{sql_escape(r["type"])}, '
        f'{sql_escape(r["hours_open"])}::time, '
        f'{sql_escape(r["hours_close"])}::time, '
        f'{str(r["is_24h"]).lower()}, '
        f'{str(r["accessible"]).lower()}, '
        f'{str(r["baby_change"]).lower()}, '
        "'seoul_open_data'"
        ')'
    )

UPSERT_HEAD = (
    'INSERT INTO public.toilets '
    '(external_id, name, address, location, district, type, hours_open, hours_close, '
    ' is_24h, accessible, baby_change, source) VALUES\n'
)
UPSERT_TAIL = (
    '\nON CONFLICT (external_id) DO UPDATE SET '
    'name = EXCLUDED.name, '
    'address = EXCLUDED.address, '
    'location = EXCLUDED.location, '
    'district = EXCLUDED.district, '
    'type = EXCLUDED.type, '
    'hours_open = EXCLUDED.hours_open, '
    'hours_close = EXCLUDED.hours_close, '
    'is_24h = EXCLUDED.is_24h, '
    'accessible = EXCLUDED.accessible, '
    'baby_change = EXCLUDED.baby_change, '
    'source = EXCLUDED.source, '
    'source_synced_at = now(), '
    'deleted_at = NULL, '
    'updated_at = now();\n'
)

chunks = []
for i in range(0, len(records), CHUNK):
    batch = records[i:i + CHUNK]
    sql = UPSERT_HEAD + ',\n  '.join(row_to_values(r) for r in batch) + UPSERT_TAIL
    chunks.append(sql)

for idx, sql in enumerate(chunks, 1):
    path = Path(OUTDIR) / f'chunk_{idx:03d}.sql'
    path.write_text(sql, encoding='utf-8')

print(f'Wrote {len(chunks)} chunks to {OUTDIR}/chunk_NNN.sql ({CHUNK} rows each)', file=sys.stderr)
print(f'Each chunk is roughly {len(chunks[0]) // 1024}KB', file=sys.stderr)
