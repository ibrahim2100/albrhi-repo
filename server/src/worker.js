//
//  Albrhi licence server.
//
//  ── The shape of it ──────────────────────────────────────────────────────────────────
//
//  The device holds a licence signed for **seven days** and renews it in the background. The
//  server decides what that licence says; the device only verifies a signature it can check
//  offline. So revocation is real — withdraw a licence and the device stops within a week — and a
//  flat network is not an outage: there are six days of slack before anybody notices.
//
//  **The token format is unchanged from the offline keys.** `ALB1.<payload>.<signature>`, ECDSA
//  P-256 over SHA-256, DER. The same Objective-C verifier reads both, which means the offline path
//  still works with no server at all: a key issued on the Mac by `tools/licence.py` is the way
//  back in if this Worker is ever unreachable.
//
//  ── What is deliberately not here ────────────────────────────────────────────────────
//
//  No accounts, no passwords, no email. A device has no credential to present and nothing on the
//  device API is worth protecting with one: every response is either a licence that device is
//  already entitled to, or a refusal. The admin side is one bearer token, compared in constant
//  time.
//
//  No personal data. A device is sixteen random hex characters the panel generated; the server
//  never learns anything else about it, and there is nothing in KV that identifies a person
//  beyond a note the buyer wrote about themselves.
//
//  Copyright (C) Ibrahim Ismail AL-Rahn. GPLv3.
//

const TOKEN_DAYS = 7;               // how long a signed licence lasts before it must be renewed
const TRIAL_DAYS = 7;               // the free trial, once per device
const MAX_NOTE = 120;
const MAX_BODY = 4096;

const enc = new TextEncoder();

// ── Encoding ──────────────────────────────────────────────────────────────────────────

const b64u = (bytes) =>
  btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

function pemToBytes(pem) {
  const body = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
}

//
// WebCrypto signs **P1363** — r and s as two fixed 32-byte halves. `Security.framework` verifies
// **DER**. A wrong conversion here does not fail loudly: it mints licences that look perfectly
// well-formed and are refused by every phone, which is the worst shape a bug can take in a
// licence server. This exact function is the one already proved against the real Objective-C
// verifier before the browser panel shipped.
//
function p1363ToDer(raw) {
  const half = raw.length / 2;
  const int = (bytes) => {
    let i = 0;
    while (i < bytes.length - 1 && bytes[i] === 0) i++;   // DER integers are minimal
    let v = bytes.slice(i);
    if (v[0] & 0x80) v = Uint8Array.from([0, ...v]);       // and signed, so keep them positive
    return Uint8Array.from([0x02, v.length, ...v]);
  };
  const body = Uint8Array.from([...int(raw.slice(0, half)), ...int(raw.slice(half))]);
  return Uint8Array.from([0x30, body.length, ...body]);
}

let signingKeyPromise = null;

function signingKey(env) {
  // Imported once per isolate rather than per request: `importKey` is not free, and a Worker
  // isolate serves many requests. Cached as the promise, so two requests arriving together share
  // one import instead of racing to do it twice.
  if (!signingKeyPromise) {
    signingKeyPromise = crypto.subtle.importKey(
      'pkcs8', pemToBytes(env.SIGNING_KEY),
      { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'],
    );
  }
  return signingKeyPromise;
}

async function mintToken(env, payload) {
  // Sorted keys and no spaces, matching tools/licence.py and the browser panel exactly. The bytes
  // signed have to be reproducible; three issuers that serialise differently are three formats.
  const json = JSON.stringify(payload, Object.keys(payload).sort());
  const body = b64u(enc.encode(json));

  const raw = new Uint8Array(await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' }, await signingKey(env), enc.encode('ALB1.' + body),
  ));
  return 'ALB1.' + body + '.' + b64u(p1363ToDer(raw));
}

async function sha256Hex(text, bytes) {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(text)));
  return [...digest.slice(0, bytes)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// ── Codes ─────────────────────────────────────────────────────────────────────────────

// Crockford's alphabet: no I, L, O or U. These are read down a phone line and typed by hand, so
// there is no 1/I and no 0/O to mishear. The device folds the confusable characters back before
// hashing, and this must fold them the same way or the two sides never agree.
const CODE_ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

function normaliseCode(typed) {
  let out = '';
  for (const raw of (typed || '').toUpperCase()) {
    let c = raw;
    if (c === 'O') c = '0';
    if (c === 'I' || c === 'L') c = '1';
    if (c === 'U') c = 'V';
    if (CODE_ALPHABET.includes(c)) out += c;
  }
  // The ALB prefix is written for the reader and survives the filter above ("A1B" once folded),
  // so it has to come off deliberately.
  if (out.length > 12 && out.startsWith('A1B')) out = out.slice(3);
  return out;
}

function mintCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  let out = '';
  for (let i = 0; i < 12; i++) out += CODE_ALPHABET[bytes[i] % 32];
  return out;
}

const pretty = (code) => 'ALB-' + code.slice(0, 4) + '-' + code.slice(4, 8) + '-' + code.slice(8);

// ── Helpers ───────────────────────────────────────────────────────────────────────────

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      // The admin panel is served from GitHub Pages, a different origin, so it needs this to read
      // any response at all. Devices are not browsers and do not care.
      'access-control-allow-origin': '*',
      'access-control-allow-headers': 'authorization, content-type',
      'access-control-allow-methods': 'GET, POST, OPTIONS',
    },
  });

const isDevice = (value) => typeof value === 'string' && /^[0-9a-f]{16}$/.test(value);

/// Constant-time comparison for the admin token.
///
/// A `!==` on a secret leaks its length and, in principle, its prefix through timing. This costs
/// nothing and removes the question.
function sameSecret(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function isAdmin(request, env) {
  const header = request.headers.get('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  return Boolean(env.ADMIN_TOKEN) && sameSecret(token, env.ADMIN_TOKEN);
}

async function readBody(request) {
  const text = await request.text();
  if (text.length > MAX_BODY) return null;
  try { return JSON.parse(text || '{}'); } catch (e) { return null; }
}

const clean = (text) =>
  typeof text === 'string'
    // Control characters out, everything else kept -- Arabic included, which is what a buyer
    // here actually writes their name in.
    //
    // Written as escapes rather than as the raw bytes it used to be. A regex holding real
    // control characters is invisible in an editor, survives a copy-paste by luck, and cannot
    // be reviewed in a diff -- and this repository's own tooling refuses to run a command
    // containing them, which is how it was noticed at all.
    ? text.replace(/[\u0000-\u001f\u007f]/g, '').trim().slice(0, MAX_NOTE)
    : '';

const now = () => Math.floor(Date.now() / 1000);

//
// **Every key under a prefix, not the first thousand.** `KV.list()` returns at most 1,000 keys and
// a `cursor` for the rest; the four callers below each read the first page only, so past a thousand
// licences the panel's counts, the shop list and -- worst -- the backup would silently stop at the
// first page. A backup that is quietly incomplete is worse than none: it is believed.
//
async function listAll(env, prefix) {
  const keys = [];
  let cursor;
  do {
    const page = await env.DB.list({ prefix, cursor });
    keys.push(...page.keys);
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  return keys;
}

/// Every key in KV, in one place.
///
/// Prefixes rather than separate namespaces: one binding, and `list({ prefix })` is what the
/// admin state call is built on.
const K = {
  request: (dev) => `req:${dev}`,
  licence: (dev) => `lic:${dev}`,
  code: (hash) => `code:${hash}`,
  // **Never deleted, on purpose.** The licence it created expires and can be replaced; this is
  // the record that the free week was already spent, and it has to outlive everything else or
  // the trial is not once per device, it is once per week.
  trial: (dev) => `trial:${dev}`,

  // **A shop, and the devices that activated from it.**
  //
  // A store licence is the opposite of every other one here: one code, any number of devices, no
  // person named. That is what a shop sells -- and the reason it lives on the server rather than
  // being compiled into the dylib is everything the compiled version could not do. The shop's
  // window can be extended without rebuilding anything, it can be withdrawn, and the panel can
  // say how many devices are actually using it.
  store: (id) => `store:${id}`,
  storeDevice: (id, dev) => `sdev:${id}:${dev}`,
};

//
// **What a licence covers, carried in the field that already existed.**
//
// `tier` has been on every token since this server was written, defaulting to `suite`. It is read
// as a *scope* now rather than as a label, which costs no new field and leaves every licence
// already issued working exactly as it did: absent or `suite` means everything.
//
//   suite        the jailbreak licence -- Albrhi and every tweak in it
//   apps         the shared code -- every separately installed tweak
//   app:<name>   one tweak alone: app:instagram, app:youtube, app:twitter, app:tiktok
//   trial        the free week, unchanged
//
// An unknown value is refused here rather than stored: the device reads anything it does not
// recognise as "everything", which is the right direction for an old build meeting a new server
// and the wrong one for a typo in the panel.
const APPS = ['instagram', 'youtube', 'twitter', 'tiktok'];

function cleanTier(value, fallback) {
  if (typeof value !== 'string' || !value) return fallback;
  if (value === 'suite' || value === 'apps' || value === 'trial' || value === 'lifetime') return value;
  if (value.startsWith('app:') && APPS.includes(value.slice(4))) return value;
  return fallback;
}

// ── A licence, and the token for it ───────────────────────────────────────────────────

/// Turns a stored licence into a fresh short-lived token, or says why not.
async function tokenFor(env, dev, licence) {
  if (!licence) return { state: 'none' };
  if (licence.revoked) return { state: 'revoked' };

  const until = licence.until || 0;
  if (until > 0 && until <= now()) return { state: 'expired', until };

  // **The token expires at the earlier of seven days and the licence's own end.** Without the
  // second half, a licence with two days left would hand out a token good for seven — and the
  // device would go on working five days past what was paid for, with the server unable to say
  // anything about it.
  const expiry = Math.min(now() + TOKEN_DAYS * 86400, until > 0 ? until : Infinity);

  const token = await mintToken(env, {
    v: 1,
    id: licence.id,
    dev,
    tier: licence.tier || 'suite',
    iat: now(),
    exp: expiry,
    until,                       // so the device can show the real end date, not the renewal date
    ...(licence.note ? { for: licence.note } : {}),
  });

  return { state: 'ok', token, until, tier: licence.tier || 'suite' };
}

// ── Routes ────────────────────────────────────────────────────────────────────────────

//
// **What the device says about itself, kept beside the licence.**
//
// The check-in already carries the device id; it now also carries which tweak is asking, that
// tweak's version, and the app it is inside. That is the whole of what a licence's own page has
// to show — *which* apps a key is actually running in and at what version — and it is answered by
// the devices themselves rather than by asking the owner to remember.
//
// Bounded on purpose: at most eight products, each one line, each overwritten by the next
// check-in. A record that grows with every launch is a record that eventually costs money to
// store and tells nobody anything more than its last line did.
//
function noteInstall(licence, body) {
  const product = clean(body.product).slice(0, 24);
  if (!licence || !product) return licence;

  const installs = { ...(licence.installs || {}) };
  installs[product] = {
    version: clean(body.version).slice(0, 24),
    app: clean(body.app).slice(0, 40),
    at: now(),
  };

  // Oldest out when there are more than eight. Four tweaks ship today; the cap is for a device
  // that has been through several of them, not a limit anybody should ever meet.
  const keys = Object.keys(installs);
  if (keys.length > 8) {
    keys.sort((a, b) => (installs[a].at || 0) - (installs[b].at || 0));
    for (const stale of keys.slice(0, keys.length - 8)) delete installs[stale];
  }

  return { ...licence, installs };
}

//
// **Activating a store copy.**
//
// The dylib is built for one shop and sends that shop's own code. What comes back is an ordinary
// signed token -- so renewal, grace, revocation and the seven-day window all work exactly as they
// do for a named licence, with no second mechanism to keep in step. What is different is only
// what the server checks: a code rather than a device, and no limit on how many devices ask.
//
// The device is recorded, which is the whole reason this moved off the compiled-in code: a shop
// that cannot see how many people are using its copies cannot decide whether to renew.
//
async function deviceStore(request, env) {
  const body = await readBody(request);
  if (!body || !isDevice(body.dev)) return json({ error: 'bad device' }, 400);

  const id = clean(body.store).toLowerCase().slice(0, 24);
  if (!id) return json({ state: 'unknown' }, 404);

  const store = await env.DB.get(K.store(id), 'json');
  if (!store) return json({ state: 'unknown' }, 404);
  if (store.revoked) return json({ state: 'revoked' }, 403);

  // The code is compared, not the store name: a build says which shop it is for, and the person
  // types what the shop gave them. Both have to agree.
  const given = clean(body.code).toLowerCase().replace(/[\s-]/g, '');
  if (!given || given !== String(store.code || '').toLowerCase()) {
    return json({ state: 'wrong_code' }, 403);
  }

  const until = store.until || 0;
  if (until > 0 && until <= now()) return json({ state: 'expired', until }, 403);

  // One line per device, overwritten on every activation. Enough to count them and to say when
  // each was last seen; nothing about the person, because there is nothing to know.
  const seen = await env.DB.get(K.storeDevice(id, body.dev), 'json');
  await env.DB.put(K.storeDevice(id, body.dev), JSON.stringify({
    first: seen?.first || now(),
    last: now(),
    product: clean(body.product).slice(0, 24),
    version: clean(body.version).slice(0, 24),
  }));

  const expiry = Math.min(now() + TOKEN_DAYS * 86400, until > 0 ? until : Infinity);

  const token = await mintToken(env, {
    v: 1,
    id: `store:${id}`,
    dev: body.dev,
    tier: `store:${id}`,
    iat: now(),
    exp: expiry,
    until,
    for: store.name || id,
  });

  return json({ state: 'ok', token, until, tier: `store:${id}` });
}

async function deviceHello(request, env) {
  const body = await readBody(request);
  if (!body || !isDevice(body.dev)) return json({ error: 'bad device' }, 400);

  const licence = await env.DB.get(K.licence(body.dev), 'json');
  const answer = await tokenFor(env, body.dev, licence);

  // Written only for a licence that exists, and only when something changed worth writing: a
  // check-in from a device with no licence is not a record, it is noise.
  if (licence && clean(body.product)) {
    const updated = noteInstall(licence, body);
    const before = licence.installs?.[clean(body.product)];
    const after = updated.installs[clean(body.product)];

    // Once an hour per product, or when the version changes. Without this every launch is a KV
    // write, which is a bill rather than a diagnostic.
    if (!before || before.version !== after.version || (after.at - (before.at || 0)) > 3600) {
      await env.DB.put(K.licence(body.dev), JSON.stringify(updated));
    }
  }

  // Whether a request is already waiting travels with the answer, so the panel on the phone can
  // say "asked, waiting" instead of offering to ask again and stacking duplicates.
  const pending = await env.DB.get(K.request(body.dev), 'json');
  return json({ ...answer, pending: Boolean(pending) });
}

async function deviceRequest(request, env) {
  const body = await readBody(request);
  if (!body || !isDevice(body.dev)) return json({ error: 'bad device' }, 400);

  const days = Math.min(3650, Math.max(1, parseInt(body.days, 10) || 365));

  const existing = await env.DB.get(K.request(body.dev), 'json');

  // One open request per device, updated rather than appended. Otherwise a person who taps twice
  // fills the inbox with the same question, and the inbox is the thing that has to stay readable.
  //
  // **Who is asking travels with it.** A request that is only a device code makes the panel a
  // list of hex strings: approving one means remembering which conversation it belonged to, which
  // is exactly the bookkeeping a person came to the panel to avoid.
  await env.DB.put(K.request(body.dev), JSON.stringify({
    dev: body.dev,
    days,
    lifetime: Boolean(body.lifetime),
    name: clean(body.name),
    contact: clean(body.contact),
    note: clean(body.note),
    ts: existing?.ts || now(),
    seen: now(),
  }), { expirationTtl: 90 * 86400 });

  return json({ ok: true, pending: true });
}

async function deviceRedeem(request, env) {
  const body = await readBody(request);
  if (!body || !isDevice(body.dev)) return json({ error: 'bad device' }, 400);

  const code = normaliseCode(body.code);
  if (code.length !== 12) return json({ state: 'malformed' }, 400);

  const hash = await sha256Hex(code, 8);
  const record = await env.DB.get(K.code(hash), 'json');
  if (!record) return json({ state: 'unknown' }, 404);

  if (record.revoked) return json({ state: 'revoked' }, 403);
  if (record.rb > 0 && record.rb <= now()) return json({ state: 'window_closed' }, 403);

  // **A code binds to the first device that redeems it, and afterwards only that device.**
  // Re-redeeming from the same phone is fine -- reinstalling the panel should not cost somebody
  // their licence -- but a code passed to a friend does nothing, which is the whole difference
  // between this and the published-list scheme it replaces.
  if (record.dev && record.dev !== body.dev) return json({ state: 'already_used' }, 403);

  const licence = {
    id: hash,
    tier: record.tier || 'suite',
    note: record.note || `code ${pretty(code)}`,
    // The clock starts at redemption, not at minting: a code sold in January and used in March
    // runs a year from March, or somebody quietly got two months less than they paid for.
    until: record.dev ? record.until : now() + record.days * 86400,
    revoked: false,
    source: 'code',
    code: hash,

    // **The code as it was typed, kept apart from `note`.** `note` is editable from the panel and
    // an edit that clears it would take the one record of which code was used with it -- the same
    // "one field, two meanings" fault the name and the note already cost a round trip over.
    codeText: pretty(code),
  };

  await env.DB.put(K.licence(body.dev), JSON.stringify(licence));
  await env.DB.put(K.code(hash), JSON.stringify({
    ...record, dev: body.dev, redeemed: record.redeemed || now(), until: licence.until,
  }));
  await env.DB.delete(K.request(body.dev));

  return json(await tokenFor(env, body.dev, licence));
}

///
/// The free week, once per device.
///
/// **What this cannot promise, said plainly:** the device id is a random value the panel writes
/// once, so somebody who wipes Albrhi's preferences gets a new id and a second trial. There is no
/// fix for that which does not involve a real device identifier -- which was deliberately not used
/// here, for the privacy reason and because it is not readable from every process. The trial is a
/// convenience for honest people, not a lock, and it is worth building as long as nobody mistakes
/// it for one.
///
/// It refuses a device that already has a licence rather than replacing it: somebody who has paid
/// pressing the free button by accident must not end up with seven days.
///
async function deviceTrial(request, env) {
  const body = await readBody(request);
  if (!body || !isDevice(body.dev)) return json({ error: 'bad device' }, 400);

  const spent = await env.DB.get(K.trial(body.dev), 'json');
  if (spent) return json({ state: 'trial_used', at: spent.at }, 403);

  const existing = await env.DB.get(K.licence(body.dev), 'json');
  if (existing && !existing.revoked && (existing.until === 0 || existing.until > now())) {
    return json({ state: 'already_licensed' }, 409);
  }

  const licence = {
    id: await sha256Hex(`trial:${body.dev}:${now()}`, 6),
    tier: 'trial',
    note: clean(body.note) || 'تجربة',
    until: now() + TRIAL_DAYS * 86400,
    revoked: false,
    source: 'trial',
  };

  await env.DB.put(K.licence(body.dev), JSON.stringify(licence));

  // Written before the token is returned, and with no expiry of its own. If this write failed and
  // the token still went out, the week would be free every week.
  await env.DB.put(K.trial(body.dev), JSON.stringify({ at: now(), until: licence.until }));
  await env.DB.delete(K.request(body.dev));

  return json(await tokenFor(env, body.dev, licence));
}


// ── Admin ─────────────────────────────────────────────────────────────────────────────

async function adminState(env) {
  //
  // **A key `list()` returns is not a key that still has a value**, and spreading the `null` it
  // answers with produced a row carrying nothing but an id.
  //
  // KV's list index is eventually consistent and lags a delete by up to about a minute. So for
  // that minute an approved request came back as `{key}` alone -- the panel drew a blank row, and
  // its approve button then posted `dev: undefined`, which the server refused. From the outside
  // that is a button that does nothing, which is exactly how it was reported.
  //
  // Dropped rather than repaired: a record that is gone is gone, and the honest thing for this
  // call to say is that there is nothing there.
  //
  const gather = async (prefix) => {
    const keys = await listAll(env, prefix);
    const rows = await Promise.all(keys.map(async (k) => {
      const value = await env.DB.get(k.name, 'json');
      return value ? { key: k.name.slice(prefix.length), ...value } : null;
    }));
    return rows.filter(Boolean);
  };

  const [requests, licences, codes, trials] = await Promise.all([
    gather('req:'), gather('lic:'), gather('code:'), gather('trial:'),
  ]);

  // Codes come back without anything that could reconstruct one. The server stores only hashes,
  // so there is nothing to strip -- said here because it is the kind of guarantee that quietly
  // stops being true when somebody adds a convenience field.
  return json({ ok: true, now: now(), requests, licences, codes, trials });
}

//
// **Everything, as one file, because there is otherwise no copy of any of it.**
//
// Every licence sold, every code, every trial record and every shop lives in one KV namespace
// with no export and no history: an account locked, a namespace deleted, or a mistake in this
// very file passing over a `delete`, and there is nothing to restore from — not even a list of
// who the customers are.
//
// Deliberately the raw records rather than a tidied shape: a backup is read by whoever is
// putting the thing back together, and the useful form for that is exactly what the store held.
// Nothing secret is added by this route that /admin/state did not already return; the codes are
// hashes there and hashes here.
//
// The records themselves, shared by the export route and the daily backup so the two cannot
// drift into describing different things.
async function exportAll(env) {
  const gather = async (prefix) => {
    const keys = await listAll(env, prefix);
    const rows = await Promise.all(keys.map(async (k) => {
      const value = await env.DB.get(k.name, 'json');
      return value ? { key: k.name, value } : null;
    }));
    return rows.filter(Boolean);
  };

  const [licences, requests, codes, trials, stores, rest] = await Promise.all([
    gather('lic:'), gather('req:'), gather('code:'), gather('trial:'), gather('store:'),
    gather('sdev:'),   // a shop's activated devices; the prefix K.storeDevice writes
  ]);

  return {
    ok: true,
    at: now(),
    format: 1,
    counts: {
      licences: licences.length, requests: requests.length, codes: codes.length,
      trials: trials.length, stores: stores.length, storeDevices: rest.length,
    },
    records: [...licences, ...requests, ...codes, ...trials, ...stores, ...rest],
  };
}

async function adminExport(env) {
  return json(await exportAll(env));
}

//
// **The daily copy.** The export above is a button somebody has to press; the largest unmitigated
// risk in this project was that nothing pressed it. A cron trigger (wrangler.toml) runs this once a
// day and keeps the last thirty.
//
// Two destinations, and which one is used is a fact about the deployment, said in the status:
//
//   * **R2** when a bucket is bound as `BACKUP` -- a copy outside the KV namespace, which is what
//     protects against the namespace itself being deleted or the account being locked out of KV.
//     Setup is in README.md; it is not bound by default because creating the bucket is the owner's
//     step, and a binding to a bucket that does not exist fails the whole deploy.
//   * **KV** otherwise, under `backup:<date>` with a 35-day expiry. Honestly weaker -- same
//     account, same namespace -- and it protects only against a mistake in a handler, not against
//     losing the namespace. The status says `store: "kv"` so nobody mistakes one for the other.
//
// `backup:` is none of the prefixes `exportAll` gathers, so a backup never contains backups.
//
const BACKUP_KEEP_DAYS = 30;

async function runBackup(env) {
  const started = now();
  const day = new Date(started * 1000).toISOString().slice(0, 10);
  let status;

  try {
    const body = JSON.stringify(await exportAll(env));
    let store;

    if (env.BACKUP) {
      await env.BACKUP.put(`backup/${day}.json`, body, { httpMetadata: { contentType: 'application/json' } });
      store = 'r2';

      // Older than the window goes; list pages are followed for the same reason as above.
      const cutoff = started - BACKUP_KEEP_DAYS * 86400;
      let cursor;
      do {
        const page = await env.BACKUP.list({ prefix: 'backup/', cursor });
        for (const object of page.objects) {
          if (Math.floor(new Date(object.uploaded).getTime() / 1000) < cutoff) await env.BACKUP.delete(object.key);
        }
        cursor = page.truncated ? page.cursor : undefined;
      } while (cursor);
    } else {
      await env.DB.put(`backup:${day}`, body, { expirationTtl: 35 * 86400 });
      store = 'kv';
    }

    status = { ok: true, at: started, day, store, bytes: body.length };
  } catch (error) {
    // Recorded, not thrown: a failed backup that only exists in a log nobody reads is how the
    // last one went unnoticed. The status is what the panel shows.
    status = { ok: false, at: started, day, error: String(error && error.message || error).slice(0, 200) };
  }

  await env.DB.put('backupstatus', JSON.stringify(status));
  return status;
}

async function adminBackupStatus(env) {
  const status = await env.DB.get('backupstatus', 'json');
  return json({ ok: true, status: status || null, bound: Boolean(env.BACKUP) });
}

async function adminApprove(request, env) {
  const body = await readBody(request);
  if (!body || !isDevice(body.dev)) return json({ error: 'bad device' }, 400);

  const existing = await env.DB.get(K.licence(body.dev), 'json');

  //
  // **Three ways to move an end date, and they are different questions.**
  //
  //   extend  (default) — add days to whatever is left. Renewing early must not throw away the
  //                       days already paid for, which is why this is the default and why it
  //                       counts from `until` rather than from today.
  //   set               — this many days from today, whatever there was before. The only way to
  //                       *shorten* a licence, and the honest name for it: it does not "reduce
  //                       by", it replaces.
  //   until             — an exact date. What you reach for when somebody paid to a date rather
  //                       than for a duration.
  //
  // A negative `days` under `extend` shortens too, which is the same arithmetic said the other
  // way round, and is what the panel's "−30" button sends.
  //
  const mode = ['set', 'until', 'lifetime'].includes(body.mode) ? body.mode : 'extend';

  const live = existing && !existing.revoked && existing.until > now();
  let until;

  if (mode === 'lifetime') {
    // **Zero means no end, and it is not a sentinel bolted on.** Every date comparison here is
    // already written as `until > 0 && ...`, because a licence with no end date was always a
    // shape this had to survive; lifetime is that shape given a name rather than a new branch
    // through every check.
    until = 0;
  } else if (mode === 'until') {
    until = parseInt(body.until, 10) || 0;
    if (until < now()) return json({ error: 'that date has passed' }, 400);
  } else if (mode === 'set') {
    const days = Math.min(3650, Math.max(0, parseInt(body.days, 10) || 0));
    until = now() + days * 86400;
  } else if (body.days === undefined) {
    //
    // **Editing a name is not editing a term.**
    //
    // An approval with no `days` used to fall into the arithmetic below, where a missing number
    // reads as zero and zero is refused as "no change asked for" — so changing a name, a number
    // or a scope on its own was answered with a 400, and from the app that is a save that
    // silently refuses. Absent keeps, which is the same rule this record already follows for
    // `name`, `contact` and `note`, applied to the one field that had been left out of it.
    //
    // A device with no licence yet is a different question: issuing one with no term at all is
    // not a thing to guess at, so it is refused in words that say which half is missing.
    //
    if (!existing) return json({ error: 'no term given for a new licence' }, 400);
    until = existing.until;
  } else {
    const days = Math.min(3650, Math.max(-3650, parseInt(body.days, 10) || 0));
    if (days === 0) return json({ error: 'no change asked for' }, 400);
    until = (live ? existing.until : now()) + days * 86400;

    // Never backwards past today: "shorten by a year" on a licence with a month left means it
    // ends now, not eleven months ago. A date in the past would still read as expired, but it
    // would also make the ledger say something that never happened.
    if (until < now()) until = now();
  }

  const licence = {
    id: existing?.id || (await sha256Hex(`${body.dev}:${now()}:${crypto.randomUUID()}`, 6)),
    // Lifetime is a *term*, not a scope, and conflating the two is how a lifetime licence for
    // one app silently became a lifetime licence for everything. The term lives in `until` (0),
    // so `tier` is free to say only what is covered.
    tier: cleanTier(body.tier, existing?.tier || 'suite'),
    // Absent keeps, empty clears -- the same rule as the two fields below, and for the same
    // reason: `||` cannot tell "not mentioned" from "deliberately emptied".
    note: body.note === undefined ? (existing?.note || '') : clean(body.note),

    // **Two fields, not one line of prose.** They arrived that way on the request and were being
    // flattened into `note` on approval — which is fine to read and useless to search: a phone
    // number buried in a sentence cannot be matched against a number somebody types with spaces
    // or dashes in it. Kept apart, they are searchable and the panel can show them in columns.
    //
    // **Absent keeps, empty clears** — and `||` cannot tell those apart. Written as `|| existing`
    // it meant a name could be changed and never removed: clearing the box sent an empty string,
    // which is falsy, so the old value came straight back. A field that cannot be emptied is a
    // field that cannot be corrected.
    // Carried through every edit: these are what the device and the redemption said, not
    // something the panel's operator types, and an approval must not quietly erase them.
    ...(existing?.codeText ? { codeText: existing.codeText } : {}),
    ...(existing?.code ? { code: existing.code } : {}),
    ...(existing?.installs ? { installs: existing.installs } : {}),

    name: body.name === undefined ? (existing?.name || '') : clean(body.name),
    contact: body.contact === undefined ? (existing?.contact || '') : clean(body.contact),
    until,
    // Approving a revoked device brings it back. Anything else would mean revoke is a one-way
    // door with no handle on the other side, which is not a thing to build into billing.
    revoked: false,
    source: existing?.source || 'approved',
    ...(existing?.code ? { code: existing.code } : {}),
    // Kept so the ledger can say what happened rather than only what is true now.
    history: [...(existing?.history || []).slice(-9),
              { at: now(), mode, until, was: existing?.until || 0 }],
  };

  await env.DB.put(K.licence(body.dev), JSON.stringify(licence));
  await env.DB.delete(K.request(body.dev));

  return json({ ok: true, licence });
}

async function adminDecline(request, env) {
  const body = await readBody(request);
  if (!body || !isDevice(body.dev)) return json({ error: 'bad device' }, 400);
  await env.DB.delete(K.request(body.dev));
  return json({ ok: true });
}

async function adminRevoke(request, env) {
  const body = await readBody(request);
  if (!body || !isDevice(body.dev)) return json({ error: 'bad device' }, 400);

  const licence = await env.DB.get(K.licence(body.dev), 'json');
  if (!licence) return json({ error: 'no licence' }, 404);

  // Marked rather than deleted. A deleted licence is indistinguishable from one that never
  // existed, and "was this revoked or did I never issue it" is a question worth being able to
  // answer six months later.
  await env.DB.put(K.licence(body.dev), JSON.stringify({
    ...licence, revoked: true, revokedAt: now(),
  }));

  if (licence.code) {
    const record = await env.DB.get(K.code(licence.code), 'json');
    if (record) {
      await env.DB.put(K.code(licence.code),
                       JSON.stringify({ ...record, revoked: true, revokedAt: now() }));
    }
  }

  return json({ ok: true, note: `stops within ${TOKEN_DAYS} days` });
}

async function adminRestore(request, env) {
  const body = await readBody(request);
  if (!body || !isDevice(body.dev)) return json({ error: 'bad device' }, 400);

  const licence = await env.DB.get(K.licence(body.dev), 'json');
  if (!licence) return json({ error: 'no licence' }, 404);

  const { revoked, revokedAt, ...rest } = licence;
  await env.DB.put(K.licence(body.dev), JSON.stringify({ ...rest, revoked: false }));
  return json({ ok: true });
}

///
/// Removes a licence outright, and optionally the record that its device used the free week.
///
/// **Deleting and revoking are different acts and both are worth having.** Revoking marks the
/// licence withdrawn and keeps it, so "was this taken away or did I never issue it" is answerable
/// six months later. Deleting is for a test, a duplicate, or a mistake -- a row that should never
/// have existed rather than one whose story ended.
///
/// The trial marker is only removed when asked for, because it is the one record here that is
/// meant to outlive everything else: clearing it hands that device another free week.
///
async function adminDelete(request, env) {
  const body = await readBody(request);
  if (!body || !isDevice(body.dev)) return json({ error: 'bad device' }, 400);

  await env.DB.delete(K.licence(body.dev));
  await env.DB.delete(K.request(body.dev));
  if (body.trial) await env.DB.delete(K.trial(body.dev));

  return json({ ok: true, note: `the device stops within ${TOKEN_DAYS} days, or at its next check` });
}

//
// **The shops, and how many devices each one is being used on.**
//
// A store licence has no person and no device attached, so the only meaningful thing to show
// about it is how far it has spread and when it stops -- which is exactly what a shop asks before
// renewing. Counted from the device records the activations wrote, not from a number kept by
// hand: a counter that is incremented is a counter that drifts.
//
async function adminStores(request, env) {
  const keys = await listAll(env, 'store:');

  const stores = [];
  for (const key of keys) {
    const id = key.name.slice('store:'.length);
    const store = await env.DB.get(key.name, 'json');
    if (!store) continue;

    // Devices are listed rather than counted in the record: KV's list is the only count that
    // cannot disagree with what is actually stored.
    const seen = { keys: await listAll(env, `sdev:${id}:`) };

    let recent = 0;
    const week = now() - 7 * 86400;
    const devices = [];

    for (const entry of seen.keys) {
      const row = await env.DB.get(entry.name, 'json');
      if (!row) continue;
      if ((row.last || 0) > week) recent++;
      devices.push({ dev: entry.name.split(':').pop(), ...row });
    }

    devices.sort((a, b) => (b.last || 0) - (a.last || 0));

    stores.push({
      id,
      ...store,
      devices: devices.length,
      recent,
      // Enough to look at, not the whole list: a shop with ten thousand activations should not
      // send ten thousand rows to a page nobody scrolls to the end of.
      sample: devices.slice(0, 50),
    });
  }

  return json({ ok: true, stores });
}

/// Creates a shop, or changes one: its code, its name, when it stops, whether it is withdrawn.
async function adminStore(request, env) {
  const body = await readBody(request);
  if (!body) return json({ error: 'bad body' }, 400);

  const id = clean(body.id).toLowerCase().replace(/[^a-z0-9_-]/g, '').slice(0, 24);
  if (!id) return json({ error: 'bad id' }, 400);

  const existing = await env.DB.get(K.store(id), 'json');

  // Absent keeps, empty clears -- the rule the licence fields already follow, and for the same
  // reason: `||` cannot tell "not mentioned" from "deliberately emptied", which is what made a
  // name uncorrectable once.
  const store = {
    name: body.name === undefined ? (existing?.name || id) : clean(body.name),
    site: body.site === undefined ? (existing?.site || '') : clean(body.site),
    code: body.code === undefined ? (existing?.code || id) : clean(body.code).toLowerCase(),
    until: body.until === undefined ? (existing?.until || 0) : (parseInt(body.until, 10) || 0),
    revoked: body.revoked === undefined ? Boolean(existing?.revoked) : Boolean(body.revoked),
    iat: existing?.iat || now(),
  };

  // Days, as the panel sends them: from today, not added to what was there. A shop renewing for
  // three months means three months from now.
  if (body.days !== undefined) {
    const days = Math.min(3650, Math.max(0, parseInt(body.days, 10) || 0));
    store.until = days > 0 ? now() + days * 86400 : 0;
  }

  await env.DB.put(K.store(id), JSON.stringify(store));
  return json({ ok: true, store: { id, ...store } });
}

async function adminCodes(request, env) {
  const body = await readBody(request);
  if (!body) return json({ error: 'bad body' }, 400);

  const count = Math.min(200, Math.max(1, parseInt(body.count, 10) || 1));
  const days = Math.min(3650, Math.max(1, parseInt(body.days, 10) || 365));
  const window = Math.min(3650, Math.max(1, parseInt(body.window, 10) || 90));
  const tier = cleanTier(body.tier, 'suite');

  const minted = [];
  for (let i = 0; i < count; i++) {
    const code = mintCode();
    const hash = await sha256Hex(code, 8);

    await env.DB.put(K.code(hash), JSON.stringify({
      days, window, tier, rb: now() + window * 86400, iat: now(),
      note: clean(body.note), revoked: false, dev: null,
    }));

    minted.push(pretty(code));
  }

  // **Returned once and never again.** The server keeps hashes, so it genuinely cannot show these
  // a second time -- a store of live codes is a store worth stealing, and not having one is
  // cheaper than defending one.
  return json({ ok: true, codes: minted, note: 'shown once — the server keeps only hashes' });
}

// ── Entry ─────────────────────────────────────────────────────────────────────────────

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(runBackup(env));
  },

  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '') || '/';

    if (request.method === 'OPTIONS') return json({ ok: true });

    if (!env.SIGNING_KEY) {
      // Named plainly. A deployment with no secret set would otherwise fail inside importKey with
      // a message nobody can act on.
      return json({ error: 'SIGNING_KEY is not set on this deployment' }, 503);
    }

    try {
      if (path === '/' || path === '/v1/health') {
        return json({ ok: true, service: 'albrhi-licence', tokenDays: TOKEN_DAYS });
      }

      if (path === '/v1/pubkey') {
        // Derived from the private key rather than stored beside it, so the two can never
        // disagree about which keypair this deployment actually signs with.
        const priv = await crypto.subtle.importKey(
          'pkcs8', pemToBytes(env.SIGNING_KEY),
          { name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign'],
        ).catch(() => null);
        if (!priv) return json({ error: 'SIGNING_KEY is not a PKCS#8 P-256 key' }, 500);

        const jwk = await crypto.subtle.exportKey('jwk', priv);
        const b64uToBytes = (t) => Uint8Array.from(
          atob(t.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - t.length % 4) % 4)),
          (c) => c.charCodeAt(0));
        const point = Uint8Array.from([0x04, ...b64uToBytes(jwk.x), ...b64uToBytes(jwk.y)]);
        return json({ ok: true, point: [...point].map((b) => b.toString(16).padStart(2, '0')).join('') });
      }

      if (request.method === 'POST' && path === '/v1/hello')   return deviceHello(request, env);
      if (request.method === 'POST' && path === '/v1/request') return deviceRequest(request, env);
      if (request.method === 'POST' && path === '/v1/redeem')  return deviceRedeem(request, env);
      if (request.method === 'POST' && path === '/v1/store')   return deviceStore(request, env);
      if (request.method === 'POST' && path === '/v1/trial')   return deviceTrial(request, env);

      if (path.startsWith('/admin/')) {
        if (!isAdmin(request, env)) return json({ error: 'unauthorised' }, 401);

        if (path === '/admin/state')   return adminState(env);
        if (path === '/admin/approve') return adminApprove(request, env);
        if (path === '/admin/decline') return adminDecline(request, env);
        if (path === '/admin/revoke')  return adminRevoke(request, env);
        if (path === '/admin/restore') return adminRestore(request, env);
        if (path === '/admin/codes')   return adminCodes(request, env);
        if (path === '/admin/stores')  return adminStores(request, env);
        if (path === '/admin/store')   return adminStore(request, env);
        if (path === '/admin/delete')  return adminDelete(request, env);
        if (path === '/admin/export')  return adminExport(env);
        if (path === '/admin/backup')  return json({ ok: true, status: await runBackup(env) });
        if (path === '/admin/backup-status') return adminBackupStatus(env);
      }

      return json({ error: 'no such route' }, 404);
    } catch (error) {
      // Never the stack. A licence server's error text is read by strangers, and the one thing
      // worth knowing on this side is in the Worker's own logs.
      return json({ error: 'internal error' }, 500);
    }
  },
};
