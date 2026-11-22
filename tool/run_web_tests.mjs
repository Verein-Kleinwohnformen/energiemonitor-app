// Fuehrt die Integrationstests unter integration_test/ in einem echten Browser aus.
//
// Ablauf pro Testdatei:
//   1. `flutter run -d web-server -t <datei>` startet die Test-App.
//   2. Ein Chrome ohne Fenster oeffnet sie, dieses Skript liest die Konsole
//      ueber das DevTools-Protokoll mit.
//   3. Die Test-App meldet am Ende eine Zeile "INTEGRATION_RESULT {...}".
//
// Gedacht fuer den Aufruf innerhalb des Firebase-Emulators:
//   firebase emulators:exec --project demo-energiemonitor "node tool/run_web_tests.mjs"
//
// Warum nicht `flutter test --platform chrome`? Unter Windows ist das in
// Flutter 3.41 defekt (Pfade mit Backslash im Testserver). Dieser Weg
// funktioniert unter Windows und Linux gleich.
//
// Umgebungsvariablen:
//   CHROME_EXECUTABLE  Pfad zu Chrome oder Chromium (sonst Standardorte)
//   WEB_TEST_TIMEOUT_S Zeitlimit pro Datei in Sekunden (Standard 900)

import { spawn, execSync } from 'node:child_process';
import { mkdtempSync, readdirSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const MARKER = 'INTEGRATION_RESULT ';
const isWindows = process.platform === 'win32';
const timeoutMs = Number(process.env.WEB_TEST_TIMEOUT_S ?? 900) * 1000;

function findChrome() {
  if (process.env.CHROME_EXECUTABLE) return process.env.CHROME_EXECUTABLE;
  const candidates = isWindows
    ? [
        'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
        'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
      ]
    : ['/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser'];
  const found = candidates.find((p) => existsSync(p));
  if (!found) throw new Error('Chrome nicht gefunden. Setze CHROME_EXECUTABLE.');
  return found;
}

function killTree(child) {
  if (!child || child.exitCode !== null) return;
  try {
    if (isWindows) {
      execSync(`taskkill /PID ${child.pid} /T /F`, { stdio: 'ignore' });
    } else {
      process.kill(-child.pid, 'SIGKILL');
    }
  } catch {
    // Prozess ist schon beendet.
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitForJson(url, deadline) {
  while (Date.now() < deadline) {
    try {
      const res = await fetch(url);
      if (res.ok) return await res.json();
    } catch {
      // Noch nicht bereit.
    }
    await sleep(250);
  }
  throw new Error(`Keine Antwort von ${url}`);
}

function startFlutter(target, port) {
  const args = [
    'run', '-d', 'web-server',
    '--web-hostname', '127.0.0.1',
    '--web-port', String(port),
    '--no-pub',
    '-t', target,
  ];
  const child = spawn('flutter', args, {
    shell: isWindows,
    detached: !isWindows,
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  const ready = new Promise((resolve, reject) => {
    const onData = (buf) => {
      const text = buf.toString();
      process.stdout.write(`[flutter] ${text}`);
      if (/is being served at/i.test(text)) resolve();
    };
    child.stdout.on('data', onData);
    child.stderr.on('data', (b) => process.stderr.write(`[flutter] ${b}`));
    child.on('exit', (code) => reject(new Error(`flutter run beendet (Code ${code})`)));
  });
  return { child, ready };
}

async function runInChrome(appUrl, deadline) {
  const debugPort = 9300 + Math.floor(Math.random() * 500);
  const profile = mkdtempSync(join(tmpdir(), 'emon-webtest-'));
  const chrome = spawn(findChrome(), [
    '--headless=new',
    `--remote-debugging-port=${debugPort}`,
    `--user-data-dir=${profile}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-gpu',
    '--window-size=1280,1600',
    'about:blank',
  ], { detached: !isWindows, stdio: 'ignore' });

  try {
    const targets = await waitForJson(`http://127.0.0.1:${debugPort}/json`, deadline);
    const page = targets.find((t) => t.type === 'page');
    const ws = new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((r, j) => { ws.onopen = r; ws.onerror = j; });
    let id = 0;
    const send = (method, params = {}) => ws.send(JSON.stringify({ id: ++id, method, params }));

    const result = new Promise((resolve, reject) => {
      ws.onmessage = (event) => {
        const msg = JSON.parse(event.data);
        if (msg.method === 'Runtime.consoleAPICalled') {
          const text = msg.params.args.map((a) => a.value ?? a.description ?? '').join(' ');
          if (text.startsWith(MARKER)) {
            resolve(JSON.parse(text.slice(MARKER.length)));
          } else {
            process.stdout.write(`[browser] ${text}\n`);
          }
        } else if (msg.method === 'Runtime.exceptionThrown') {
          const d = msg.params.exceptionDetails;
          process.stdout.write(`[browser:exception] ${d.exception?.description ?? d.text}\n`);
        }
      };
      setTimeout(() => reject(new Error('Zeitlimit erreicht, kein Ergebnis')), deadline - Date.now());
    });

    send('Runtime.enable');
    send('Page.navigate', { url: appUrl });
    const outcome = await result;
    ws.close();
    return outcome;
  } finally {
    killTree(chrome);
    await sleep(300);
    try { rmSync(profile, { recursive: true, force: true }); } catch { /* egal */ }
  }
}

async function runFile(target) {
  const port = 7400 + Math.floor(Math.random() * 500);
  const deadline = Date.now() + timeoutMs;
  console.log(`\n=== ${target}`);
  const { child, ready } = startFlutter(target, port);
  try {
    await Promise.race([
      ready,
      sleep(timeoutMs).then(() => { throw new Error('flutter run nicht bereit'); }),
    ]);
    const results = await runInChrome(`http://127.0.0.1:${port}/`, deadline);
    let failed = 0;
    for (const [name, outcome] of Object.entries(results)) {
      const ok = outcome === 'success';
      if (!ok) failed++;
      console.log(`${ok ? 'OK    ' : 'FEHLER'} ${name}${ok ? '' : `\n${outcome}`}`);
    }
    if (Object.keys(results).length === 0) {
      console.log('FEHLER keine Tests gemeldet');
      failed++;
    }
    return failed;
  } finally {
    try { child.stdin.write('q\n'); } catch { /* egal */ }
    await sleep(1500);
    killTree(child);
  }
}

const files = process.argv.slice(2).length
  ? process.argv.slice(2)
  : readdirSync('integration_test')
      .filter((f) => f.endsWith('_test.dart'))
      .sort()
      .map((f) => `integration_test/${f}`);

let totalFailed = 0;
for (const file of files) {
  try {
    totalFailed += await runFile(file);
  } catch (e) {
    console.log(`FEHLER ${file}: ${e.message}`);
    totalFailed++;
  }
}
console.log(totalFailed === 0 ? '\nAlle Integrationstests gruen.' : `\n${totalFailed} Fehler.`);
process.exit(totalFailed === 0 ? 0 : 1);
