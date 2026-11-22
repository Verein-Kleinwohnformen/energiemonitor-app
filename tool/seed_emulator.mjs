// Fuellt den lokalen Firebase-Emulator (Demo-Projekt) mit Beispieldaten,
// damit sich die App ohne produktive Datenbank durchklicken laesst.
//
//   firebase emulators:start --only firestore,auth --project demo-energiemonitor
//   node tool/seed_emulator.mjs
//   flutter run -d chrome --dart-define=USE_EMULATOR=true
//
// Anmelden mit einem der Konten unten. Die Zugangsdaten gelten nur im
// Emulator und sind absichtlich Testwerte.

const PROJECT = 'demo-energiemonitor';
const FS = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`;
const AUTH = 'http://127.0.0.1:9099';
const PASSWORD = 'emulator-123456';

export const ACCOUNTS = {
  bewohner: 'bewohner@example.test', // normales Haus und Studienhaus, darf bearbeiten
  leser: 'leser@example.test', // nur lesen, normales Haus
  superadmin: 'superadmin@example.test', // verwaltet Zugriffe (Custom Claim), ohne eigene Haeuser
  neu: 'neu@example.test', // frisch registriert, nur Sandbox
};

const owner = { Authorization: 'Bearer owner', 'Content-Type': 'application/json' };

function value(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(value) } };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, value(x)])) } };
}

async function setDoc(path, data) {
  const res = await fetch(`${FS}/${path}`, {
    method: 'PATCH',
    headers: owner,
    body: JSON.stringify({ fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, value(v)])) }),
  });
  if (!res.ok) throw new Error(`${path}: ${res.status} ${await res.text()}`);
}

async function signUp(email) {
  const res = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-api-key`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: PASSWORD, returnSecureToken: true }),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(`${email}: ${JSON.stringify(body)}`);
  return body.localId;
}

/// Custom Claims setzen, wie es tool/admin/set_superadmin.mjs in der echten
/// Umgebung tut (hier mit dem Owner-Zugang des Emulators).
async function setClaims(uid, claims) {
  const res = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:update`, {
    method: 'POST',
    headers: owner,
    body: JSON.stringify({ localId: uid, customAttributes: JSON.stringify(claims) }),
  });
  if (!res.ok) throw new Error(`Claims ${uid}: ${res.status} ${await res.text()}`);
}

async function reset() {
  await fetch(`http://127.0.0.1:8080/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, { method: 'DELETE' });
  await fetch(`${AUTH}/emulator/v1/projects/${PROJECT}/accounts`, { method: 'DELETE' });
}

const day = (y, m, d) => new Date(y, m - 1, d).getTime(); // Lokalzeit Mitternacht, wie die App

/// Ein Eintrag im Format von Energy.addToFirebase() (energy.dart).
async function manual(device, uid, { type, mp, unit, purchase, usage, added, leftover, consumed, desc, provisory }) {
  const d = new Date(purchase);
  const id = `${purchase}000-${mp}-${type}`;
  const iso = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  await setDoc(`devices/${device}/manual/${d.getFullYear()}/data/${id}`, {
    sensor_id: 'app_form',
    device_id: device,
    metering_point: mp,
    date: iso,
    day: d.getDate(),
    year: d.getFullYear(),
    start_timestamp: purchase,
    end_timestamp: purchase,
    data_points: [{ timestamp: purchase, values: { added_quantity: added, leftover_quantity: leftover, consumed_quantity: consumed, unit } }],
    count: 1,
    created_at: new Date().toISOString(),
    metadata: { description: desc, purchase_date: purchase, estimated_usage_date: usage, usage_date_provisory: provisory, user_id: uid, energy_type: type },
  });
}

async function meteringPoint(device, mp, sensors, fields, lastSeen) {
  await setDoc(`devices/${device}/metering_points/${mp}`, {
    metering_point: mp,
    device_id: device,
    sensor_types: sensors,
    value_fields: fields,
    first_seen: day(2026, 4, 1),
    last_seen: lastSeen,
  });
}

/// Telemetrie der letzten 48 Stunden, alle 10 Minuten, ein Dokument pro Tag.
async function telemetry(device, mp, sensor, field, fn, lastSeen) {
  const step = 10 * 60 * 1000;
  const byDay = new Map();
  for (let t = lastSeen - 48 * 3600 * 1000; t <= lastSeen; t += step) {
    const d = new Date(t);
    const key = `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
    if (!byDay.has(key)) byDay.set(key, []);
    byDay.get(key).push({ timestamp: t, values: { [field]: Math.round(fn(d) * 10) / 10 } });
  }
  for (const points of byDay.values()) {
    const d = new Date(points[0].timestamp);
    const month = String(d.getMonth() + 1).padStart(2, '0');
    await setDoc(`devices/${device}/telemetry/${d.getFullYear()}/${month}/${mp}-${sensor}-${d.getDate()}`, {
      sensor_id: sensor,
      device_id: device,
      metering_point: mp,
      date: d.toISOString().slice(0, 10),
      day: d.getDate(),
      start_timestamp: points[0].timestamp,
      end_timestamp: points.at(-1).timestamp,
      data_points: points,
      count: points.length,
    });
  }
}

async function main() {
  await reset();
  const now = Date.now();
  const recent = now - 20 * 60 * 1000;

  const bewohner = await signUp(ACCOUNTS.bewohner);
  const leser = await signUp(ACCOUNTS.leser);
  const superadmin = await signUp(ACCOUNTS.superadmin);
  const neu = await signUp(ACCOUNTS.neu);
  await setClaims(superadmin, { superadmin: true });

  // Beispieldaten, keine echten Haeuser.
  await setDoc('monitors/demo-haus', { monitor_id: 'demo-haus', tinyhouse_name: 'Beispielhaus', tinyhouse_location: 'Beispielort' });
  await setDoc('monitors/demo-studie', {
    monitor_id: 'demo-studie',
    tinyhouse_name: 'Studienhaus',
    tinyhouse_location: 'Beispieltal',
    study_mode: true,
    study_note: 'Messjahr bis Oktober 2028 (Beispiel)',
  });

  await setDoc('monitors/sandbox_monitor', { monitor_id: 'sandbox_monitor', tinyhouse_name: 'Testmonitor', tinyhouse_location: 'Sandbox' });
  await setDoc('monitors/demo-jura', { monitor_id: 'demo-jura', tinyhouse_name: 'Haus ohne Klimasensor', tinyhouse_location: 'Beispielberg' });

  const user = (uid, email, read, edit) => ({
    user_id: uid, ...(email ? { email } : {}), monitor_read: read, monitor_edit: edit, monitor_api_keys: {}, date_created: new Date(),
  });
  await setDoc(`users/${bewohner}`, user(bewohner, ACCOUNTS.bewohner, ['demo-haus', 'demo-studie'], ['demo-haus', 'demo-studie']));
  // Altes Konto: ohne E-Mail im User-Dokument, bis es sich neu anmeldet.
  await setDoc(`users/${leser}`, user(leser, null, ['demo-haus'], []));
  await setDoc(`users/${superadmin}`, user(superadmin, ACCOUNTS.superadmin, [], []));
  await setDoc(`users/${neu}`, user(neu, ACCOUNTS.neu, ['sandbox_monitor'], ['sandbox_monitor']));

  // Haushalt nur beim Beispielhaus; beim Studienhaus fragt die App danach.
  await setDoc('monitors/demo-haus/household/2026-02-01_1', {
    valid_from: '2026-02-01', persons: 2, living_area_m2: 16, label_w_per_person: 90, updated_by: bewohner, updated_at: new Date(),
  });

  for (const device of ['demo-haus', 'demo-studie']) {
    await manual(device, bewohner, { type: 'pellets', mp: 'M2', unit: 'kg', purchase: day(2026, 3, 10), usage: day(2026, 10, 1), added: 15, leftover: 2, consumed: 0, desc: 'Restposten vom Winter', provisory: false });
    await manual(device, bewohner, { type: 'pellets', mp: 'M2', unit: 'kg', purchase: day(2026, 10, 1), usage: day(2027, 1, 15), added: 30, leftover: 5, consumed: 12, desc: 'Pellets, 2 Säcke', provisory: true });
    await manual(device, bewohner, { type: 'propane', mp: 'M1', unit: 'kg', purchase: day(2026, 7, 19), usage: day(2026, 10, 30), added: 11.5, leftover: 12, consumed: 0, desc: 'Neue Flasche', provisory: true });
    await meteringPoint(device, 'M1', ['app_form'], ['added_quantity', 'leftover_quantity', 'consumed_quantity', 'unit'], day(2026, 7, 19));
    await meteringPoint(device, 'M2', ['app_form'], ['added_quantity', 'leftover_quantity', 'consumed_quantity', 'unit'], day(2026, 10, 1));
  }

  // Beispielhaus: alles online.
  await meteringPoint('demo-haus', 'E1', ['victron'], ['power'], recent);
  await meteringPoint('demo-haus', 'E3', ['victron'], ['power'], recent);
  await meteringPoint('demo-haus', 'I2', ['shelly-3em-pro'], ['act_power', 'aprt_power', 'pf', 'voltage'], recent);
  await meteringPoint('demo-haus', 'K0', ['netatmo', 'sensirion_scd4x'], ['temperature_indoor', 'humidity_indoor', 'co2_indoor', 'temperature_outdoor'], recent);
  const sun = (d) => Math.max(0, Math.sin(((d.getHours() + d.getMinutes() / 60 - 6) / 12) * Math.PI)) * 900;
  await telemetry('demo-haus', 'E3', 'victron', 'power', sun, recent);
  await telemetry('demo-haus', 'E1', 'victron', 'power', () => 0, recent);
  await telemetry('demo-haus', 'I2', 'shelly-3em-pro', 'act_power', (d) => (d.getHours() < 7 ? 450 : 0), recent);
  await telemetry('demo-haus', 'K0', 'netatmo', 'temperature_indoor', (d) => 20.5 + 1.5 * Math.sin((d.getHours() / 24) * 2 * Math.PI), recent);
  await telemetry('demo-haus', 'K0', 'sensirion_scd4x', 'co2_indoor', (d) => (d.getHours() >= 22 || d.getHours() < 7 ? 1300 : 650), recent);

  // Studienhaus: ein Messpunkt verzoegert.
  await meteringPoint('demo-studie', 'E1', ['victron'], ['power'], recent);
  await meteringPoint('demo-studie', 'E3', ['victron'], ['power'], recent);
  await meteringPoint('demo-studie', 'K0', ['netatmo'], ['temperature_indoor', 'humidity_indoor', 'co2_indoor'], now - 3 * 3600 * 1000);

  console.log('Beispieldaten im Emulator angelegt. Konten (Passwort siehe tool/seed_emulator.mjs):');
  for (const [role, email] of Object.entries(ACCOUNTS)) console.log(`  ${role.padEnd(9)} ${email}`);
}

main().catch((e) => {
  console.error(e.message);
  console.error('Laeuft der Emulator? firebase emulators:start --only firestore,auth --project demo-energiemonitor');
  process.exit(1);
});
