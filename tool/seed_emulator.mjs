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
  await setDoc('monitors/demo-haus/household/2025-10-01_1', {
    valid_from: '2025-10-01', persons: 2, living_area_m2: 16, label_w_per_person: 90, updated_by: bewohner, updated_at: new Date(),
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

  // Faktoren wie in /config/factors der Produktion (oeffentliche Quellen),
  // dazu die Vergleichswerte fuer Watt pro Person (Etappe 3).
  await setDoc('config/factors', {
    heating_values: {
      pellets: { value: 5.0, unit: 'kWh/kg', source: 'LWF Bayern, Merkblatt 12, November 2024' },
      woodKg: { value: 4.235, unit: 'kWh/kg', source: 'LWF Bayern, Merkblatt 12, November 2024' },
      woodSter: { value: 1627.5, unit: 'kWh/Ster', source: 'LWF Bayern, Merkblatt 12, November 2024' },
      propane: { value: 12.861, unit: 'kWh/kg', source: 'BAFU, Faktenblatt CO2-Emissionsfaktoren, Januar 2026' },
      oil: { value: 9.998, unit: 'kWh/Liter', source: 'BAFU, Faktenblatt CO2-Emissionsfaktoren, Januar 2026' },
    },
    weighting_factors: {
      electricity: 2.0, pellets: 0.5, woodKg: 0.5, woodSter: 0.5, propane: 1.0, oil: 1.0, diesel: 1.0, gasoline: 1.0,
      pv_self_consumption_credit: 1.0, pv_feed_in_credit: 0.4,
      source: 'Minergie, Produktreglement Gebäudestandards Version 2026.1',
    },
    primary_energy_factors: {
      unit: 'kWh oil-eq pro kWh Endenergie',
      electricity: { total: 2.65, name: 'CH-Verbrauchermix' },
      pellets: { total: 1.18 }, woodKg: { total: 1.05 }, woodSter: { total: 1.05 },
      propane: { total: 1.22 }, oil: { total: 1.26 },
      source: 'KBOB/ecobau-Liste 2022, Version 9.0',
    },
    benchmarks: {
      target_2000w: { label: '2000-Watt-Ziel', value: 420, method: '2000watt', source: 'KWF-Energielabel, Bereich Wohnen' },
      ch_today: { label: 'Schweiz heute', value: 1300, method: '2000watt', source: 'KWF-Energielabel, Bereich Wohnen' },
    },
    updated_at: '2026-11-23',
    note: 'Beispieldaten im Emulator',
  });

  // Tageswerte der letzten 400 Tage fuer das Beispielhaus, im Format der
  // energiemonitor-api (POST /aggregate). Erfundene, aber plausible Zahlen:
  // Sonne im Sommer, Heizung und Pelletofen im Winter, einzelne Luecken.
  const r = (v, d = 3) => Math.round(v * 10 ** d) / 10 ** d;
  const today = new Date(now);
  for (let back = 400; back >= 0; back--) {
    const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() - back);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    const doy = Math.round((d - new Date(d.getFullYear(), 0, 1)) / 86400_000);
    const i = Math.round((d - new Date(2025, 0, 1)) / 86400_000);
    const season = Math.cos((2 * Math.PI * (doy - 15)) / 365);
    const noise = Math.sin(i * 1.7);
    const pv = Math.max(0.2, 2.8 - 1.8 * season + 0.8 * noise);
    const i3 = 2.1 + 0.3 * Math.sin(i * 0.9);
    const i2 = season > 0.3 ? r(1.6 * season + 0.3 * noise) : 0;
    const need = i2 + i3 + 0.08 + 0.3;
    const feed = Math.max(0, pv - need) * 0.7;
    const grid = Math.max(0, need - (pv - feed));
    const occupied = i % 9 !== 0;
    const gappy = i % 23 === 0;
    const partial = back === 0;
    const tIn = 21.6 - 1.4 * season + 0.6 * noise;
    const fire = season > 0.35 && occupied;
    const provisional = back < 20;
    const pellets = fire ? r(1.1 + 0.6 * season) : 0;
    const propane = occupied ? 0.07 : 0;
    const hourlyPv = Array.from({ length: 24 }, (_, h) => (h >= 9 && h < 16 ? r(pv / 7, 4) : 0));
    await setDoc(`devices/demo-haus/daily/${key}`, {
      date: key,
      timezone: 'Europe/Zurich',
      energy_kwh: { E1: r(grid), E2: r(feed), E3: r(pv), I2: i2, I3: r(i3), A1: 0.08 },
      energy_sensor: { E1: 'victron', E2: 'victron', E3: 'victron', I2: 'shelly-3em-pro', I3: 'shelly-3em-pro', A1: 'shelly-3em-pro' },
      hourly_kwh: { E3: hourlyPv },
      availability: { E1: gappy ? 0.82 : 1, E3: gappy ? 0.82 : 1, I2: 1, I3: 1, K1: 0.98, K2: 0.98, K3: 0.98, K4: 0.98 },
      climate: {
        t_in_median: r(tIn, 1), t_in_p05: r(tIn - 2, 1), t_in_p95: r(tIn + 2.4, 1), t_in_max: r(tIn + 3, 1),
        rh_in_median: r(48 + 6 * season + 3 * noise, 0), co2_median: r(occupied ? 880 + 200 * season : 520, 0),
        co2_max: occupied ? 1650 : 560, t_out_mean: r(10 - 9 * season, 1), t_out_min: r(5 - 9 * season, 1),
        t_out_max: r(15 - 10 * season, 1), hours_over_28: season < -0.75 ? r(2.5 - 2 * season + noise, 1) : 0,
        t_in_mean_08_20: r(tIn + 0.8, 1),
      },
      hourly_climate: {
        t_in: Array.from({ length: 24 }, (_, h) => r(tIn + 1.6 * Math.sin(((h - 9) / 24) * 2 * Math.PI), 1)),
        co2: Array.from({ length: 24 }, (_, h) => (occupied ? (h >= 22 || h < 7 ? r(1250 + 250 * season, 0) : r(700 + 50 * noise, 0)) : 520)),
      },
      climate_source: 'netatmo',
      occupied,
      occupancy_source: 'sensirion_scd4x',
      co2_peak: occupied ? 1820 : 470,
      fire_events: fire ? [{ start: '06:00', end: '10:20', start_ts: d.getTime(), end_ts: d.getTime(), rise_k_per_h: 6.1, weight: 4.33 }] : [],
      fire_source: 'netatmo',
      manual_alloc: {
        pellets: {
          quantity: pellets, unit: 'kg', method: 'ofensignatur', provisional, incomplete: false,
          fires: fire ? 1 : 0, by_metering_point: { M2: pellets },
        },
        propane: {
          quantity: propane, unit: 'kg', method: 'bewohnte_tage', provisional, incomplete: false,
          by_metering_point: { M1: propane },
        },
      },
      manual_kwh_estimated: { pellets: r(pellets * 5), propane: r(propane * 12.861) },
      partial,
      data_until: partial ? recent : d.getTime() + 86399_000,
      computed_at: new Date().toISOString(),
      version: 1,
    });
  }

  console.log('Beispieldaten im Emulator angelegt. Konten (Passwort siehe tool/seed_emulator.mjs):');
  for (const [role, email] of Object.entries(ACCOUNTS)) console.log(`  ${role.padEnd(9)} ${email}`);
}

main().catch((e) => {
  console.error(e.message);
  console.error('Laeuft der Emulator? firebase emulators:start --only firestore,auth --project demo-energiemonitor');
  process.exit(1);
});
