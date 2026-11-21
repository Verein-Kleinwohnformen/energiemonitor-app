// Startet den Firebase-Emulator (Demo-Projekt, nur lokal), fuehrt die
// Browser-Integrationstests aus und raeumt danach auf.
//
//   node tool/run_integration.mjs                       alle Tests
//   node tool/run_integration.mjs integration_test/x.dart  eine Datei
//
// Unter Windows beendet `firebase emulators:exec` den Java-Prozess des
// Firestore-Emulators nicht immer. Darum werden alte Emulator-Prozesse vor
// und nach dem Lauf gestoppt.

import { spawnSync, execSync } from 'node:child_process';

const isWindows = process.platform === 'win32';

function stopStaleEmulators() {
  try {
    if (isWindows) {
      execSync(
        'powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \\"Name=\'java.exe\'\\" | ' +
          "Where-Object { $_.CommandLine -match 'cloud-firestore-emulator' } | " +
          'ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"',
        { stdio: 'ignore' },
      );
    } else {
      execSync("pkill -f cloud-firestore-emulator || true", { stdio: 'ignore' });
    }
  } catch {
    // Nichts zu stoppen.
  }
}

const files = process.argv.slice(2).join(' ');
stopStaleEmulators();
const result = spawnSync(
  'firebase',
  [
    'emulators:exec',
    '--only', 'firestore,auth',
    '--project', 'demo-energiemonitor',
    `"node tool/run_web_tests.mjs ${files}"`,
  ],
  { stdio: 'inherit', shell: true },
);
stopStaleEmulators();
process.exit(result.status ?? 1);
