"""Turn a licence-server backup into the file `wrangler kv bulk put` takes.

    python3 tools/backup-to-kv-bulk.py backup-2026-10-11.json > bulk.json
    npx wrangler kv bulk put bulk.json --namespace-id <id from server/wrangler.toml>

A backup (server/src/worker.js, `exportAll`) is `{format: 1, records: [{key, value}, ...]}` with the
value as the parsed record. KV stores the *string*, so each value is serialised back. Nothing is
invented and nothing is dropped: the count printed to stderr is checked against the file's own.

Reads `format: 1` only. A different format is refused rather than guessed at, because a restore that
quietly mangles every licence is worse than one that stops.
"""
import json
import sys

if len(sys.argv) != 2:
    sys.exit('usage: backup-to-kv-bulk.py <backup.json>  >  bulk.json')

with open(sys.argv[1], encoding='utf-8') as handle:
    backup = json.load(handle)

if backup.get('format') != 1 or not isinstance(backup.get('records'), list):
    sys.exit('not a format-1 licence backup (expected {"format": 1, "records": [...]})')

bulk = []
for record in backup['records']:
    if not isinstance(record, dict) or 'key' not in record or 'value' not in record:
        sys.exit('a record without key and value: %r' % (record,))
    bulk.append({'key': record['key'], 'value': json.dumps(record['value'], separators=(',', ':'))})

declared = sum((backup.get('counts') or {}).values())
if declared and declared != len(bulk):
    sys.exit('the file says %d records and holds %d — refusing to write a partial restore' % (declared, len(bulk)))

json.dump(bulk, sys.stdout, ensure_ascii=False)
print('%d records' % len(bulk), file=sys.stderr)
