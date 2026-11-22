// Traegt die E-Mail jedes Kontos aus Firebase Auth einmalig in sein
// User-Dokument (/users/{uid}.email) ein, damit die Verwaltung alle Konten
// mit E-Mail zeigt. Neue Konten schreiben die E-Mail selbst (Registrierung
// und jede Anmeldung mit der neuen App-Version).
//
//   node tool/admin/backfill_emails.mjs --project <projekt>           Probelauf
//   node tool/admin/backfill_emails.mjs --project <projekt> --apply   ausfuehren
//
// Aendert nur das Feld email. Konten ohne User-Dokument werden gemeldet und
// mit --create-missing als Dokument ohne Zugriffe angelegt (monitor_read und
// monitor_edit leer), damit der Superadmin sie zuordnen kann.
// Zugang siehe common.mjs (gcloud-Login oder EMULATOR=1).

import { connect, parseArgs } from './common.mjs';

const args = parseArgs(process.argv.slice(2));
const api = connect(args.values.project);
const apply = args.flags.has('apply');
const createMissing = args.flags.has('create-missing');

console.log(`Projekt ${api.project}${api.emulator ? ' (Emulator)' : ''}${apply ? '' : ', Probelauf ohne --apply'}`);

const users = await api.listUsers();
let updated = 0;
let same = 0;
let missing = 0;
let noEmail = 0;
for (const u of users) {
  if (!u.email) {
    noEmail++;
    continue;
  }
  const doc = await api.getDoc(`users/${u.localId}`);
  if (!doc) {
    missing++;
    console.log(`  ohne User-Dokument: ${u.localId} ${u.email}${createMissing ? ' -> wird angelegt' : ''}`);
    if (apply && createMissing) {
      await api.patchFields(`users/${u.localId}`, {
        user_id: u.localId,
        email: u.email,
        monitor_read: [],
        monitor_edit: [],
        monitor_api_keys: {},
      });
    }
    continue;
  }
  if (doc.fields?.email?.stringValue === u.email) {
    same++;
    continue;
  }
  updated++;
  console.log(`  ${u.localId}: E-Mail ${u.email}`);
  if (apply) await api.patchFields(`users/${u.localId}`, { email: u.email });
}
console.log(
  `${users.length} Konten: ${updated} ${apply ? 'nachgetragen' : 'nachzutragen'}, ${same} schon aktuell, ` +
    `${missing} ohne User-Dokument, ${noEmail} ohne E-Mail im Login.`,
);
if (!apply) console.log('Probelauf. Mit --apply ausfuehren.');
