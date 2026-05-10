#!/usr/bin/env python3
"""
zirizima — POST transformed toilet records to Supabase via the
bulk_insert_toilets RPC function.

Reads the same JSON the import_seoul_toilets.py script does, applies the
same transforms, then POSTs in batches via stdlib urllib (no extra deps).

Usage:
    python3 bulk_post.py [INPUT_JSON] [BATCH_SIZE]
"""

import json
import sys
import os
import time
import urllib.request
import urllib.error

# Reuse the transform logic from the sibling script.
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from import_seoul_toilets import (  # noqa: E402
    parse_hours, detect_type, parse_accessible, parse_baby_change, is_valid_coord
)

INPUT = sys.argv[1] if len(sys.argv) > 1 else '/Users/yeom/Downloads/서울시 공중화장실 위치정보.json'
BATCH = int(sys.argv[2]) if len(sys.argv) > 2 else 500

SUPABASE_URL = 'https://strdafvajmxpcwinlzdv.supabase.co'
SUPABASE_KEY = 'sb_publishable_GnyAhOMQohjiXl3gTeESPQ_gFkqo1Jo'

# -------------------------------------------------------------------------
# Load + transform
# -------------------------------------------------------------------------
with open(INPUT, encoding='utf-8') as f:
    payload = json.load(f)

raw_rows = payload['DATA']
records = []
skipped = 0

for raw in raw_rows:
    lat = raw.get('coord_y')
    lng = raw.get('coord_x')
    if not is_valid_coord(lat, lng):
        skipped += 1
        continue

    name_ko = (raw.get('conts_name') or '').strip() or '공중화장실'
    addr_ko = (raw.get('addr_new') or raw.get('addr_old') or '').strip() or name_ko
    open_h, close_h, is_24h = parse_hours(raw.get('value_02'))

    records.append({
        'external_id': f'seoul:{raw["objectid"]}',
        'name': {'ko': name_ko},
        'address': {'ko': addr_ko},
        'lat': float(lat),
        'lng': float(lng),
        'district': (raw.get('gu_name') or '').strip() or None,
        'type': detect_type(name_ko, raw.get('value_08')),
        'hours_open': open_h or '',
        'hours_close': close_h or '',
        'is_24h': is_24h,
        'accessible': parse_accessible(raw.get('value_05')),
        'baby_change': parse_baby_change(raw.get('value_06')),
    })

print(f'Loaded {len(raw_rows)} rows, {len(records)} valid, {skipped} skipped')

# -------------------------------------------------------------------------
# POST in batches
# -------------------------------------------------------------------------
RPC = f'{SUPABASE_URL}/rest/v1/rpc/bulk_insert_toilets'
HEADERS = {
    'apikey': SUPABASE_KEY,
    'Authorization': f'Bearer {SUPABASE_KEY}',
    'Content-Type': 'application/json',
}

total = 0
fails = 0
t0 = time.time()

for i in range(0, len(records), BATCH):
    batch = records[i:i + BATCH]
    body = json.dumps({'payload': batch}, ensure_ascii=False).encode('utf-8')
    req = urllib.request.Request(RPC, data=body, headers=HEADERS, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            inserted = int(resp.read().decode('utf-8').strip())
            total += inserted
            print(f'  batch {i//BATCH + 1}: +{inserted} rows  (running total: {total})')
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', errors='replace')
        print(f'  batch {i//BATCH + 1}: HTTP {e.code} — {body[:300]}', file=sys.stderr)
        fails += 1
    except Exception as e:
        print(f'  batch {i//BATCH + 1}: ERROR — {e}', file=sys.stderr)
        fails += 1

dt = time.time() - t0
print(f'\nDone. {total} rows inserted/updated in {dt:.1f}s ({fails} failed batches).')
