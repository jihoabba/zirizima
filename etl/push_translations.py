#!/usr/bin/env python3
"""Push translated toilet names + addresses to Supabase via update_toilet_i18n RPC."""

import json, sys, time, urllib.request, urllib.error

SRC = '/tmp/zirizima-import/translations.json'
SUPABASE_URL = 'https://strdafvajmxpcwinlzdv.supabase.co'
SUPABASE_KEY = 'sb_publishable_GnyAhOMQohjiXl3gTeESPQ_gFkqo1Jo'
RPC = f'{SUPABASE_URL}/rest/v1/rpc/update_toilet_i18n'
BATCH = 500

with open(SRC) as f:
    rows = json.load(f)
print(f'Loaded {len(rows)} translations from {SRC}')

headers = {
    'apikey': SUPABASE_KEY,
    'Authorization': f'Bearer {SUPABASE_KEY}',
    'Content-Type': 'application/json',
}

total = 0
fails = 0
t0 = time.time()
for i in range(0, len(rows), BATCH):
    batch = rows[i:i + BATCH]
    body = json.dumps({'payload': batch}, ensure_ascii=False).encode('utf-8')
    req = urllib.request.Request(RPC, data=body, headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            n = int(resp.read().decode().strip())
            total += n
            print(f'  batch {i // BATCH + 1}: {n} updated  (running: {total})')
    except urllib.error.HTTPError as e:
        print(f'  batch {i // BATCH + 1}: HTTP {e.code} — {e.read().decode()[:200]}', file=sys.stderr)
        fails += 1

print(f'\nDone. {total} rows updated in {time.time() - t0:.1f}s ({fails} failures).')
