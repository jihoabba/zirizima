#!/usr/bin/env python3
"""
zirizima — Korean → English translator for toilet names and addresses.

Strategy:
  1) Romanize Hangul to Roman per Revised Romanization of Korean (RR).
  2) Apply post-processing rules for common suffixes (역, 공원, 시장, ...).
  3) Translate the 25 Seoul district names via lookup.
  4) Numbers, parentheses, and English fragments stay as-is.

Output: writes UPDATE rows to /tmp/zirizima-import/translations.json
        (one record per toilet with translated name + address)

Run:   python3 translate_to_english.py
"""

import json
import re
import sys
import os
from pathlib import Path

INPUT = sys.argv[1] if len(sys.argv) > 1 else '/Users/yeom/Downloads/서울시 공중화장실 위치정보.json'
OUT_PATH = '/tmp/zirizima-import/translations.json'

# Reuse the validity check from the importer
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from import_seoul_toilets import is_valid_coord  # noqa: E402

# =========================================================================
# Hangul Romanization (Revised Romanization, simplified — no liaison rules)
# =========================================================================

HANGUL_BASE = 0xAC00
HANGUL_END = 0xD7A3

INITIALS = ['g','kk','n','d','tt','r','m','b','pp','s','ss','','j','jj','ch','k','t','p','h']
VOWELS   = ['a','ae','ya','yae','eo','e','yeo','ye','o','wa','wae','oe','yo','u','wo','we','wi','yu','eu','ui','i']
FINALS   = ['','k','k','ks','n','nj','nh','t','l','lk','lm','lb','ls','lt','lp','lh','m','p','ps','t','t','ng','j','t','k','t','p','t']

def romanize_syllable(ch):
    code = ord(ch)
    if HANGUL_BASE <= code <= HANGUL_END:
        idx = code - HANGUL_BASE
        ini = INITIALS[idx // (21 * 28)]
        vow = VOWELS[(idx % (21 * 28)) // 28]
        fin = FINALS[idx % 28]
        return ini + vow + fin
    return ch

def romanize(text):
    return ''.join(romanize_syllable(c) for c in text)

def romanize_capitalized(text):
    """Romanize and capitalize the first letter of each space-delimited word."""
    rom = romanize(text)
    return ' '.join(w.capitalize() if w and w[0].isalpha() else w for w in rom.split(' '))

# =========================================================================
# Lookup tables
# =========================================================================

# 25 Seoul districts (구) — official English names per the city
DISTRICTS = {
    '강남구': 'Gangnam-gu',  '강동구': 'Gangdong-gu',  '강북구': 'Gangbuk-gu',
    '강서구': 'Gangseo-gu',  '관악구': 'Gwanak-gu',    '광진구': 'Gwangjin-gu',
    '구로구': 'Guro-gu',     '금천구': 'Geumcheon-gu', '노원구': 'Nowon-gu',
    '도봉구': 'Dobong-gu',   '동대문구': 'Dongdaemun-gu', '동작구': 'Dongjak-gu',
    '마포구': 'Mapo-gu',     '서대문구': 'Seodaemun-gu','서초구': 'Seocho-gu',
    '성동구': 'Seongdong-gu','성북구': 'Seongbuk-gu',  '송파구': 'Songpa-gu',
    '양천구': 'Yangcheon-gu','영등포구': 'Yeongdeungpo-gu','용산구': 'Yongsan-gu',
    '은평구': 'Eunpyeong-gu','종로구': 'Jongno-gu',    '중구': 'Jung-gu',
    '중랑구': 'Jungnang-gu',
}

# Suffix mappings — applied as last-token substitution
SUFFIX_MAP = [
    ('역사',   'Stn.'),
    ('역',    'Stn.'),
    ('구청',   '-gu Office'),
    ('주민센터', 'Community Center'),
    ('동사무소', 'Community Center'),
    ('시청',   'City Hall'),
    ('공원',   'Park'),
    ('어린이공원', "Children's Park"),
    ('시장',   'Market'),
    ('박물관',  'Museum'),
    ('미술관',  'Art Museum'),
    ('도서관',  'Library'),
    ('파출소',  'Police Box'),
    ('치안센터', 'Police Box'),
    ('경찰서',  'Police Station'),
    ('지하상가', 'Underground Arcade'),
    ('상가',   'Arcade'),
    ('복지관',  'Welfare Center'),
    ('문화원',  'Cultural Center'),
    ('문화회관', 'Cultural Hall'),
    ('문화센터', 'Cultural Center'),
    ('체육관',  'Gymnasium'),
    ('경기장',  'Stadium'),
    ('빌딩',   'Building'),
    ('센터',   'Center'),
    ('공중화장실', 'Public Toilet'),
    ('화장실',  'Toilet'),
    ('터미널',  'Terminal'),
    ('교회',   'Church'),
    ('성당',   'Cathedral'),
    ('절',    'Temple'),
    ('사찰',   'Temple'),
    ('등산로',  'Trail'),
    ('전망대',  'Observatory'),
    ('휴게소',  'Rest Area'),
    ('관광안내소','Tourist Info Center'),
    ('우체국',  'Post Office'),
    ('소방서',  'Fire Station'),
    ('보건소',  'Public Health Center'),
    ('학교',   'School'),
    ('대학교',  'University'),
    ('병원',   'Hospital'),
    ('약국',   'Pharmacy'),
    ('주차장',  'Parking Lot'),
    ('정류장',  'Bus Stop'),
    ('정거장',  'Bus Stop'),
    ('휴게실',  'Lounge'),
    ('공중',   'Public'),
]

# Inline word substitutions (whole-word replace in romanized output too painful;
# easier to substitute Korean → English BEFORE romanization).
# Order matters — multi-word phrases must come before their constituent words.
WORD_SUBS = [
    # Multi-word/compound phrases first
    ('한국전력공사', 'KEPCO'),
    ('한국생산성본부', 'Korea Productivity Center'),
    ('대한민국', 'Korea'),
    ('서울특별시', 'Seoul'),
    ('서울시', 'Seoul'),
    ('번출구', ' Exit'),
    ('번 출구', ' Exit'),
    # Building / wing
    ('전시동', 'Exhibition Hall'),
    ('관리동', 'Admin Bldg'),
    ('본관', 'Main Hall'),
    ('별관', 'Annex'),
    ('신관', 'New Wing'),
    ('구관', 'Old Wing'),
    ('동관', 'East Wing'),
    ('서관', 'West Wing'),
    ('남관', 'South Wing'),
    ('북관', 'North Wing'),
    # Single words
    ('출구', 'Exit'),
    ('지하', 'Underground '),
    ('지상', ''),
    ('남자', "Men's"),
    ('여자', "Women's"),
    ('남녀', 'Unisex'),
    ('장애인', 'Accessible'),
    ('어린이', "Children's"),
    ('영유아', 'Infant'),
    ('한국', 'Korea'),
    ('국립', 'National'),
    ('국제', 'International'),
    ('서울본부', 'Seoul HQ'),
    ('본부', 'HQ'),
    ('아트', 'Art'),
    ('예술', 'Art'),
    ('플라자', 'Plaza'),
    ('프라자', 'Plaza'),
    ('센타', 'Center'),
    ('극장', 'Theater'),
    ('타워', 'Tower'),
    ('몰', 'Mall'),
    ('호텔', 'Hotel'),
    ('교회', 'Church'),
    ('성당', 'Cathedral'),
    ('사찰', 'Temple'),
    ('절', 'Temple'),
    ('종합', 'General'),
    ('개방', 'Public'),
    ('공중', 'Public'),
    ('공공', 'Public'),
    ('주차', 'Parking'),
    ('정문', 'Main Gate'),
    ('후문', 'Rear Gate'),
    ('1동', 'Bldg 1'),  ('2동', 'Bldg 2'),  ('3동', 'Bldg 3'),
    ('4동', 'Bldg 4'),  ('5동', 'Bldg 5'),  ('6동', 'Bldg 6'),
    ('7동', 'Bldg 7'),  ('8동', 'Bldg 8'),  ('9동', 'Bldg 9'),
    ('A동', 'Bldg A'),  ('B동', 'Bldg B'),  ('C동', 'Bldg C'),
    ('D동', 'Bldg D'),  ('E동', 'Bldg E'),  ('F동', 'Bldg F'),
]

# =========================================================================
# Translation
# =========================================================================

FLOOR_RE = re.compile(r'B?(\d+)층')
EXIT_RE  = re.compile(r'(\d+)번\s*출구')
NUM_RE   = re.compile(r'^(\d+)$')


def translate_floor(match):
    """Convert '1층' → '1F', 'B1층' → 'B1F'."""
    raw = match.group(0)
    if raw.startswith('B'):
        return f"B{match.group(1)}F"
    return f"{match.group(1)}F"


def translate_exit(match):
    """Convert '1번 출구' → 'Exit 1'."""
    return f"Exit {match.group(1)}"


def translate_text(text):
    """Translate a Korean text to English using rules + romanization."""
    if not text:
        return text

    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text.strip())

    # Floor / Exit patterns first (they contain digits we don't want romanized)
    text = EXIT_RE.sub(translate_exit, text)
    text = FLOOR_RE.sub(translate_floor, text)

    # Word-level substitutions (Korean → English)
    for ko, en in WORD_SUBS:
        text = text.replace(ko, ' ' + en + ' ')

    # Suffix / token-level substitutions — these often appear at the end of a phrase
    for ko, en in SUFFIX_MAP:
        text = re.sub(re.escape(ko), ' ' + en + ' ', text)

    # District names
    for ko, en in DISTRICTS.items():
        text = text.replace(ko, ' ' + en + ' ')

    # Romanize remaining Hangul, syllable by syllable, capitalizing word starts
    out_parts = []
    word_start = True
    for ch in text:
        if HANGUL_BASE <= ord(ch) <= HANGUL_END:
            rom = romanize_syllable(ch)
            if word_start and rom and rom[0].isalpha():
                rom = rom[0].upper() + rom[1:]
                word_start = False
            out_parts.append(rom)
        else:
            out_parts.append(ch)
            if ch.isspace() or ch in '(),-/':
                word_start = True
            else:
                word_start = False

    out = ''.join(out_parts)

    # Liaison: Korean phonetic rule — "ㅇ + 로" reads as "Jongno", not "Jongro".
    # Apply the common transformations after romanization (cheap pattern fix).
    LIAISON = [
        (r'\bjongro\b', 'Jongno'),
        (r'\bJongro\b', 'Jongno'),
        (r'(\w*ng)ro', r'\1no'),     # generic ng+ro → ng+no  (e.g., Daehakro → Daehakno-ro is wrong; this targets ng+ro only)
    ]
    for pat, repl in LIAISON:
        out = re.sub(pat, repl, out)

    # Hyphenate -ro / -gil / -dong at the end of a romanized street/place name
    # so "Yulgokro" → "Yulgok-ro", "Insadonggil" → "Insadong-gil"
    out = re.sub(r'([A-Za-z]{2,})ro\b',  r'\1-ro',  out)
    out = re.sub(r'([A-Za-z]{2,})gil\b', r'\1-gil', out)

    # Cleanup: collapse multiple spaces, trim, fix "Stn ." style spacing
    out = re.sub(r'\s+', ' ', out).strip()
    out = re.sub(r'\s+([,.)])', r'\1', out)
    out = re.sub(r'(\()\s+', r'\1', out)
    out = out.strip(' -')

    return out


def translate_address(addr):
    """Address-specific cleanup to make it look like 'Seoul, Jongno-gu, Jongno 69'."""
    if not addr:
        return addr
    en = translate_text(addr)
    # Drop literal "Seoul," prefix duplicates
    en = re.sub(r'^Seoul\s+', 'Seoul, ', en)
    en = re.sub(r'\s+', ' ', en).strip().rstrip(',')
    return en


# =========================================================================
# Build translations from input JSON
# =========================================================================

with open(INPUT, encoding='utf-8') as f:
    payload = json.load(f)

translations = []
sample = []

for raw in payload['DATA']:
    if not is_valid_coord(raw.get('coord_y'), raw.get('coord_x')):
        continue

    name_ko = (raw.get('conts_name') or '').strip() or '공중화장실'
    addr_ko = (raw.get('addr_new') or raw.get('addr_old') or '').strip() or name_ko

    name_en = translate_text(name_ko)
    addr_en = translate_address(addr_ko)

    translations.append({
        'external_id': f'seoul:{raw["objectid"]}',
        'name':    {'ko': name_ko, 'en': name_en},
        'address': {'ko': addr_ko, 'en': addr_en},
    })

    if len(sample) < 12:
        sample.append({'ko': name_ko, 'en': name_en, 'addr_ko': addr_ko, 'addr_en': addr_en})

Path(OUT_PATH).parent.mkdir(parents=True, exist_ok=True)
with open(OUT_PATH, 'w', encoding='utf-8') as f:
    json.dump(translations, f, ensure_ascii=False)

print(f'Wrote {len(translations)} translation records to {OUT_PATH}')
print('\nSample translations:')
for s in sample:
    print(f"  KO: {s['ko']:<35}  →  EN: {s['en']}")
    print(f"      {s['addr_ko'][:50]}")
    print(f"      → {s['addr_en'][:80]}")
    print()
