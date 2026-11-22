// Startet den Firebase-Emulator (Demo-Projekt, nur lokal), fuehrt die
// Browser-Integrationstests aus und raeumt danach auf.
//
//   node tool/run_integration.mjs                       alle Tests
//   node tool/run_integration.mjs integration_test/x.dart  eine Datei
//
// Die Tests nutzen eigene Ports (firebase.test.json: Firestore 8180, Auth
// 9199), ein laufender Dev-Emulator auf 8080/9099 bleibt unberuehrt.
// Unter Windows beendet `firebase emulators:exec` den Java-Prozess des
// Firestore-Emulators nicht immer. Darum wird der Test-Emulator (Port 8180)
// vor und nach dem Lauf gestoppt, nur dieser.

import { spawnSync, execSync } from 'node:child_process';

const isWindows = process.platform === 'win32';

function stopStaleEmulators() {
  try {
    if (isWindows) {
      execSync(
        'powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \\"Name=\'java.exe\'\\" | ' +
          "Where-Object { $_.CommandLine -match 'cloud-firestore-emulator' -and $_.CommandLine -match '8180' } | " +
          'ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"',
        { stdio: 'ignore' },
      );
    } else {
      execSync("pkill -f 'cloud-firestore-emulator.*8180' || true", { stdio: 'ignore' });
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
    '--config', 'firebase.test.json',
    '--only', 'firestore,auth',
    '--project', 'demo-energiemonitor',
    `"node tool/run_web_tests.mjs ${files}"`,
  ],
  { stdio: 'inherit', shell: true },
);
stopStaleEmulators();
process.exit(result.status ?? 1);
