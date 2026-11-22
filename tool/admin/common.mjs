// Gemeinsames fuer die Admin-Skripte: Zugang zu Identity Toolkit (Firebase
// Auth) und Firestore ueber REST, ohne zusaetzliche Pakete.
//
// Echte Umgebung: Zugangs-Token vom gcloud-Login der aufrufenden Person.
//   ACCESS_TOKEN=$(gcloud auth print-access-token --account <dein-konto>)
// Ohne ACCESS_TOKEN ruft das Skript `gcloud auth print-access-token` selbst
// auf (optional mit GCLOUD_ACCOUNT).
//
// Emulator: EMULATOR=1 (Projekt demo-energiemonitor, Ports 9099 und 8080).

import { execSync } from 'node:child_process';

export function parseArgs(argv) {
  const out = { flags: new Set(), values: {}, rest: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--project') out.values.project = argv[++i];
    else if (a.startsWith('--')) out.flags.add(a.slice(2));
    else out.rest.push(a);
  }
  return out;
}

export function connect(project) {
  const emulator = process.env.EMULATOR === '1';
  if (!emulator && !project) throw new Error('Bitte --project angeben (z.B. energiemonitor-kwf).');
  const p = emulator ? 'demo-energiemonitor' : project;
  let token = process.env.ACCESS_TOKEN;
  if (emulator) token = 'owner';
  if (!token) {
    const account = process.env.GCLOUD_ACCOUNT ? ` --account ${process.env.GCLOUD_ACCOUNT}` : '';
    token = execSync(`gcloud auth print-access-token${account}`, { encoding: 'utf8' }).trim();
  }
  const headers = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
    ...(emulator ? {} : { 'x-goog-user-project': p }),
  };
  const auth = emulator
    ? `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/${p}`
    : `https://identitytoolkit.googleapis.com/v1/projects/${p}`;
  const fs = emulator
    ? `http://127.0.0.1:8080/v1/projects/${p}/databases/(default)/documents`
    : `https://firestore.googleapis.com/v1/projects/${p}/databases/(default)/documents`;

  async function call(url, init = {}) {
    const res = await fetch(url, { ...init, headers });
    const text = await res.text();
    if (!res.ok && res.status !== 404) throw new Error(`${res.status} ${url}\n${text}`);
    return { status: res.status, body: text ? JSON.parse(text) : {} };
  }

  return {
    project: p,
    emulator,
    /// Alle Konten aus Firebase Auth (localId, email, customAttributes ...).
    async listUsers() {
      const users = [];
      let pageToken = '';
      do {
        const q = new URLSearchParams({ maxResults: '500', ...(pageToken ? { nextPageToken: pageToken } : {}) });
        const { body } = await call(`${auth}/accounts:batchGet?${q}`);
        users.push(...(body.users ?? []));
        pageToken = body.nextPageToken ?? '';
      } while (pageToken);
      return users;
    },
    async lookup(uid) {
      const { body } = await call(`${auth}/accounts:lookup`, {
        method: 'POST',
        body: JSON.stringify({ localId: [uid] }),
      });
      return body.users?.[0] ?? null;
    },
    async setClaims(uid, claims) {
      await call(`${auth}/accounts:update`, {
        method: 'POST',
        body: JSON.stringify({ localId: uid, customAttributes: JSON.stringify(claims) }),
      });
    },
    async getDoc(path) {
      const { status, body } = await call(`${fs}/${path}`);
      return status === 404 ? null : body;
    },
    /// Setzt nur die angegebenen Felder (Rest des Dokuments bleibt).
    async patchFields(path, fields) {
      const mask = Object.keys(fields).map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
      await call(`${fs}/${path}?${mask}`, {
        method: 'PATCH',
        body: JSON.stringify({ fields: Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, toValue(v)])) }),
      });
    },
  };
}

export function toValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, toValue(x)])) } };
}
