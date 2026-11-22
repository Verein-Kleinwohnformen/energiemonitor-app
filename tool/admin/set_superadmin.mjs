// Superadmin-Recht als Custom Claim im Login-Token setzen oder entfernen.
//
// Das ist der einzige Weg zu Superadmin-Rechten: die App kann Claims nicht
// setzen, und die Firestore-Rules pruefen nur den Claim im Token.
//
//   node tool/admin/set_superadmin.mjs --project <projekt> <uid> [<uid> ...]
//   node tool/admin/set_superadmin.mjs --project <projekt> --remove <uid>
//   node tool/admin/set_superadmin.mjs --project <projekt> --list
//
// Ohne --apply zeigt das Skript nur, was es tun wuerde (Probelauf).
// Andere Claims eines Kontos bleiben erhalten. Die Person muss sich danach
// einmal ab- und wieder anmelden, damit das neue Token gilt.
// Zugang siehe common.mjs (gcloud-Login oder EMULATOR=1).

import { connect, parseArgs } from './common.mjs';

const args = parseArgs(process.argv.slice(2));
const api = connect(args.values.project);
const apply = args.flags.has('apply');
const remove = args.flags.has('remove');

console.log(`Projekt ${api.project}${api.emulator ? ' (Emulator)' : ''}${apply ? '' : ', Probelauf ohne --apply'}`);

if (args.flags.has('list')) {
  const users = await api.listUsers();
  const supers = users.filter((u) => JSON.parse(u.customAttributes ?? '{}').superadmin === true);
  console.log(supers.length ? 'Superadmins:' : 'Keine Superadmins.');
  for (const u of supers) console.log(`  ${u.localId}  ${u.email ?? '(keine E-Mail)'}`);
  process.exit(0);
}

if (args.rest.length === 0) {
  console.error('Bitte mindestens eine UID angeben.');
  process.exit(1);
}

for (const uid of args.rest) {
  const user = await api.lookup(uid);
  if (!user) {
    console.log(`  ${uid}: kein Konto gefunden, uebersprungen`);
    continue;
  }
  const claims = JSON.parse(user.customAttributes ?? '{}');
  const next = { ...claims };
  if (remove) delete next.superadmin;
  else next.superadmin = true;
  const changed = JSON.stringify(claims) !== JSON.stringify(next);
  console.log(`  ${uid} ${user.email ?? ''}: ${JSON.stringify(claims)} -> ${JSON.stringify(next)}${changed ? '' : ' (unveraendert)'}`);
  if (apply && changed) await api.setClaims(uid, next);
}
console.log(apply ? 'Fertig. Betroffene Personen einmal neu anmelden lassen.' : 'Probelauf. Mit --apply ausfuehren.');
