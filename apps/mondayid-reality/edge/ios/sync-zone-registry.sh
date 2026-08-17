#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/edge/ios/App/Resources/oref-cities.json"
TMP="${OUT}.tmp"
SOURCE="https://raw.githubusercontent.com/eladnava/pikud-haoref-api/master/cities.json"
mkdir -p "$(dirname "$OUT")"
curl --fail --silent --show-error --location "$SOURCE" -o "$TMP"
python3 - "$TMP" <<'PY'
import json,sys
p=sys.argv[1]
with open(p,encoding='utf-8') as f: data=json.load(f)
assert isinstance(data,list), 'registry must be an array'
usable=[x for x in data if x.get('id') not in (None,0) and x.get('value') not in (None,'','all')]
assert len(usable) >= 1000, f'registry too small: {len(usable)}'
ids=[x['id'] for x in usable]
assert len(ids)==len(set(ids)), 'zone ids must be unique'
required=('name','name_en','name_ru','name_ar','value','countdown','lat','lng')
for i,x in enumerate(usable):
    missing=[k for k in required if k not in x]
    assert not missing, f'zone {i} missing {missing}'
for probe in ('חיפה','נהריה'):
    assert any(probe in str(x.get('value','')) or probe in str(x.get('name','')) for x in usable), f'missing probe zone {probe}'
print(f'zone registry: PASS ({len(usable)} canonical zones)')
PY
mv "$TMP" "$OUT"
