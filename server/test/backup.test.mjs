// The daily backup, run against an in-memory KV that paginates the way the real one does (a list call
// returns a page and a cursor), so the thing the backup exists to guard against -- a silent stop at
// the first page -- is what is tested. Run with:   node --test server/test/
import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/worker.js';

/** A KV that returns `pageSize` keys per list call, like the real one returns 1,000. */
function fakeKV(pageSize) {
  const store = new Map();
  return {
    store,
    async get(key, type) {
      const value = store.get(key);
      if (value === undefined) return null;
      return type === 'json' ? JSON.parse(value) : value;
    },
    async put(key, value) { store.set(key, value); },
    async delete(key) { store.delete(key); },
    async list({ prefix = '', cursor } = {}) {
      const all = [...store.keys()].filter((k) => k.startsWith(prefix)).sort();
      const from = cursor ? Number(cursor) : 0;
      const keys = all.slice(from, from + pageSize).map((name) => ({ name }));
      const done = from + pageSize >= all.length;
      return { keys, list_complete: done, cursor: done ? undefined : String(from + pageSize) };
    },
  };
}

function fakeR2(objects = {}) {
  const store = new Map(Object.entries(objects));
  return {
    store,
    async put(key, body) { store.set(key, { body, uploaded: new Date() }); },
    async delete(key) { store.delete(key); },
    async list({ prefix = '' } = {}) {
      return {
        objects: [...store.entries()].filter(([k]) => k.startsWith(prefix)).map(([key, v]) => ({ key, uploaded: v.uploaded })),
        truncated: false,
      };
    },
  };
}

function seed(kv) {
  for (let i = 0; i < 7; i++) kv.store.set(`lic:dev${i}`, JSON.stringify({ until: 0, name: `n${i}` }));
  for (let i = 0; i < 4; i++) kv.store.set(`req:dev${i}`, JSON.stringify({ days: 30 }));
  for (let i = 0; i < 5; i++) kv.store.set(`code:h${i}`, JSON.stringify({ days: 7 }));
  kv.store.set('trial:devA', JSON.stringify({ at: 1 }));
  kv.store.set('store:shop1', JSON.stringify({ name: 'shop' }));
  kv.store.set('sdev:shop1:devA', JSON.stringify({ seen: 1 }));
}

async function run(env) {
  const pending = [];
  await worker.scheduled({}, env, { waitUntil: (p) => pending.push(p) });
  await Promise.all(pending);
}

test('the KV backup holds every record, across pages', async () => {
  const DB = fakeKV(3);                    // 3 per page: 7 licences need three pages
  seed(DB);
  await run({ DB });

  const status = JSON.parse(DB.store.get('backupstatus'));
  assert.equal(status.ok, true);
  assert.equal(status.store, 'kv');

  const backup = JSON.parse(DB.store.get(`backup:${status.day}`));
  assert.deepEqual(backup.counts, { licences: 7, requests: 4, codes: 5, trials: 1, stores: 1, storeDevices: 1 });
  assert.equal(backup.records.length, 19);
});

test('a backup never contains backups or its own status', async () => {
  const DB = fakeKV(100);
  seed(DB);
  await run({ DB });
  await run({ DB });                       // the second run sees the first's output in the namespace
  const status = JSON.parse(DB.store.get('backupstatus'));
  const backup = JSON.parse(DB.store.get(`backup:${status.day}`));
  assert.equal(backup.records.length, 19);
  assert.ok(backup.records.every((r) => !r.key.startsWith('backup')));
});

test('with R2 bound, the copy goes there and old ones are removed', async () => {
  const DB = fakeKV(100);
  seed(DB);
  const old = new Date(Date.now() - 40 * 86400 * 1000);
  const BACKUP = fakeR2({ 'backup/2020-01-01.json': { body: '{}', uploaded: old } });
  await run({ DB, BACKUP });

  const status = JSON.parse(DB.store.get('backupstatus'));
  assert.equal(status.store, 'r2');
  assert.ok(BACKUP.store.has(`backup/${status.day}.json`));
  assert.ok(!BACKUP.store.has('backup/2020-01-01.json'), 'a copy older than thirty days is dropped');
  assert.ok(![...DB.store.keys()].some((k) => k.startsWith('backup:')), 'nothing went to KV');
});

test('a failure is recorded as a failure, not thrown into a log nobody reads', async () => {
  const DB = fakeKV(100);
  seed(DB);
  const BACKUP = fakeR2();
  BACKUP.put = async () => { throw new Error('bucket unreachable'); };
  await run({ DB, BACKUP });

  const status = JSON.parse(DB.store.get('backupstatus'));
  assert.equal(status.ok, false);
  assert.match(status.error, /bucket unreachable/);
});
