// Verwaltung der Zugaenge (nur Superadmin). Konten mit E-Mail, Zuordnung
// zu Haeusern mit Lesen oder Bearbeiten, Uebersicht pro Haus, Protokoll.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/services.dart';
import '../app/session_scope.dart';
import '../monitor.dart';
import '../theme/kwf_theme.dart';
import '../theme/kwf_tokens.dart';
import '../theme/kwf_widgets.dart';
import 'access.dart';

final _dateTime = DateFormat('d.M.yyyy, HH:mm');

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AppServices.of(context).admin;
    if (repo == null || !SessionScope.of(context).isSuperadmin) {
      return const Scaffold(body: Center(child: Text('Nur für Superadmins.')));
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: KwfColors.seitengrund,
        appBar: AppBar(
          title: const Text('Zugänge verwalten'),
          leading: IconButton(
            tooltip: 'Zurück',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          bottom: TabBar(
            labelStyle: kwfText(14, weight: FontWeight.w600),
            unselectedLabelStyle: kwfText(14, weight: FontWeight.w400),
            labelColor: KwfColors.anthrazit,
            unselectedLabelColor: KwfColors.textSekundaer,
            indicatorColor: KwfColors.gruen,
            tabs: const [Tab(text: 'Konten'), Tab(text: 'Häuser'), Tab(text: 'Protokoll')],
          ),
        ),
        body: StreamBuilder<List<EnergieMonitor>>(
          stream: repo.watchMonitors(),
          builder: (context, monitorsSnap) => StreamBuilder<List<Account>>(
            stream: repo.watchAccounts(),
            builder: (context, accountsSnap) {
              final error = monitorsSnap.error ?? accountsSnap.error;
              if (error != null) {
                return KwfPage(children: [
                  KwfHint('Die Konten konnten nicht geladen werden. Ist dein Konto als '
                      'Superadmin freigeschaltet? Melde dich danach einmal neu an.\n\n$error',
                      icon: Icons.error_outline),
                ]);
              }
              if (!monitorsSnap.hasData || !accountsSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final monitors = monitorsSnap.data!;
              final accounts = accountsSnap.data!;
              return TabBarView(children: [
                AccountsTab(accounts: accounts, monitors: monitors),
                MonitorsTab(accounts: accounts, monitors: monitors),
                LogTab(monitors: monitors),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

String Function(String) monitorNamer(List<EnergieMonitor> monitors) => (id) {
      for (final m in monitors) {
        if (m.id == id) return m.tinyhouseName;
      }
      return id;
    };

class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key, required this.accounts, required this.monitors});
  final List<Account> accounts;
  final List<EnergieMonitor> monitors;

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = widget.accounts.where((a) {
      if (q.isEmpty) return true;
      return [a.email, a.name, a.uid].whereType<String>().any((s) => s.toLowerCase().contains(q));
    }).toList();
    final name = monitorNamer(widget.monitors);
    return KwfPage(children: [
      TextField(
        key: const ValueKey('admin-search'),
        decoration: const InputDecoration(
          hintText: 'Suchen nach E-Mail oder Name',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
      Text('${widget.accounts.length} Konten', style: KwfText.meta),
      KwfSection(children: [
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Kein Konto gefunden.', style: KwfText.body),
          ),
        for (final a in shown)
          KwfNavRow(
            icon: Icons.person_outline,
            title: a.label,
            subtitle: _summary(a, name),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AccountAccessPage(account: a, monitors: widget.monitors),
            )),
          ),
      ]),
      if (widget.accounts.any((a) => a.email == null))
        Text(
            'Konten ohne E-Mail haben sich seit der neuen App-Version noch nicht '
            'angemeldet. Mit tool/admin/backfill_emails.mjs lassen sich die E-Mails '
            'einmalig nachtragen.',
            style: KwfText.help),
    ]);
  }

  String _summary(Account a, String Function(String) name) {
    if (a.read.isEmpty) return 'Kein Haus zugeordnet';
    final parts = a.read.map((id) => '${name(id)} (${a.edit.contains(id) ? 'bearbeiten' : 'lesen'})');
    return parts.join(', ');
  }
}

/// Zuordnung eines Kontos zu allen Haeusern.
class AccountAccessPage extends StatefulWidget {
  const AccountAccessPage({super.key, required this.account, required this.monitors});
  final Account account;
  final List<EnergieMonitor> monitors;

  @override
  State<AccountAccessPage> createState() => _AccountAccessPageState();
}

class _AccountAccessPageState extends State<AccountAccessPage> {
  final _changes = <String, Access>{};
  bool _saving = false;

  Access _current(String id) => _changes[id] ?? widget.account.accessTo(id);

  /// Haeuser im User-Dokument, die es als Monitor nicht (mehr) gibt.
  List<String> get _unknownIds => {
        ...widget.account.read,
        ...widget.account.edit,
      }.where((id) => !widget.monitors.any((m) => m.id == id)).toList();

  Future<void> _save() async {
    final a = widget.account;
    final next = applyAccess(a, _changes);
    final name = monitorNamer(widget.monitors);
    final lines = describeChanges(
      beforeRead: a.read,
      beforeEdit: a.edit,
      afterRead: next.read,
      afterEdit: next.edit,
      name: name,
    );
    if (lines.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Zugriffe ändern?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.label, style: kwfText(14, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final l in lines) Text('• $l'),
            const SizedBox(height: 8),
            Text('Die Änderung wird protokolliert.', style: KwfText.meta),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Abbrechen')),
          FilledButton(
            key: const ValueKey('admin-confirm'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('SPEICHERN'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    final session = SessionScope.read(context);
    try {
      await AppServices.of(context).admin!.saveAccess(
            account: a,
            read: next.read,
            edit: next.edit,
            actorUid: session.uid!,
            actorEmail: session.email,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Zugriffe für ${a.label} gespeichert')));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern hat nicht geklappt: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return Scaffold(
      backgroundColor: KwfColors.seitengrund,
      appBar: AppBar(
        title: Text(a.label, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          tooltip: 'Zurück',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: KwfPage(children: [
        Text(
            [
              if (a.name != null) a.name!,
              'ID ${a.uid}',
              if (a.createdAt != null) 'angelegt ${DateFormat('d.M.yyyy').format(a.createdAt!)}',
            ].join(' · '),
            style: KwfText.meta),
        Text('Bearbeiten heisst: Einträge erfassen und löschen, Haushalt ändern. '
            'Bearbeiten schliesst Lesen ein.', style: KwfText.small),
        KwfSection(children: [
          for (final m in widget.monitors)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.tinyhouseName, style: kwfText(15, weight: FontWeight.w500)),
                  Text(
                      [m.tinyhouseLocation, m.id, if (m.studyMode) 'Energiestudie'].join(' · '),
                      style: KwfText.meta),
                  const SizedBox(height: 8),
                  SegmentedButton<Access>(
                    key: ValueKey('admin-access-${m.id}'),
                    showSelectedIcon: false,
                    segments: [
                      for (final v in Access.values)
                        ButtonSegment(
                          value: v,
                          label: Text(v.label),
                        ),
                    ],
                    selected: {_current(m.id)},
                    onSelectionChanged: (s) => setState(() => _changes[m.id] = s.first),
                  ),
                ],
              ),
            ),
        ]),
        if (_unknownIds.isNotEmpty)
          KwfHint('Im Konto stehen Häuser, die es als Monitor nicht gibt: '
              '${_unknownIds.join(', ')}. Sie bleiben unverändert.'),
        KwfPrimaryButton('Speichern',
            key: const ValueKey('admin-save'), busy: _saving, onPressed: _save),
      ]),
    );
  }
}

class MonitorsTab extends StatelessWidget {
  const MonitorsTab({super.key, required this.accounts, required this.monitors});
  final List<Account> accounts;
  final List<EnergieMonitor> monitors;

  @override
  Widget build(BuildContext context) {
    return KwfPage(children: [
      Text('${monitors.length} Häuser', style: KwfText.meta),
      for (final m in monitors)
        KwfSection(
          title: m.tinyhouseName,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                  [m.tinyhouseLocation, m.id, if (m.studyMode) 'Energiestudie'].join(' · '),
                  style: KwfText.meta),
            ),
            ...() {
              final withAccess =
                  accounts.where((a) => a.accessTo(m.id) != Access.none).toList();
              if (withAccess.isEmpty) {
                return [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Noch niemand zugeordnet.', style: KwfText.body),
                  )
                ];
              }
              return [
                for (final a in withAccess)
                  KwfNavRow(
                    icon: a.accessTo(m.id) == Access.edit
                        ? Icons.edit_outlined
                        : Icons.visibility_outlined,
                    title: a.label,
                    subtitle: a.accessTo(m.id).label,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => AccountAccessPage(account: a, monitors: monitors),
                    )),
                  ),
              ];
            }(),
          ],
        ),
    ]);
  }
}

class LogTab extends StatelessWidget {
  const LogTab({super.key, required this.monitors});
  final List<EnergieMonitor> monitors;

  @override
  Widget build(BuildContext context) {
    final name = monitorNamer(monitors);
    return StreamBuilder<List<AccessLogEntry>>(
      stream: AppServices.of(context).admin!.watchLog(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final entries = snap.data!;
        return KwfPage(children: [
          Text('Letzte ${entries.length} Änderungen', style: KwfText.meta),
          KwfSection(children: [
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Noch keine Änderungen.', style: KwfText.body),
              ),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.targetEmail ?? e.targetUid, style: kwfText(14, weight: FontWeight.w600)),
                    for (final l in describeChanges(
                      beforeRead: e.beforeRead,
                      beforeEdit: e.beforeEdit,
                      afterRead: e.afterRead,
                      afterEdit: e.afterEdit,
                      name: name,
                    ))
                      Text(l, style: KwfText.small),
                    Text(
                        '${e.at == null ? '' : '${_dateTime.format(e.at!)} · '}'
                        'von ${e.actorEmail ?? e.actorUid}',
                        style: KwfText.meta),
                  ],
                ),
              ),
          ]),
        ]);
      },
    );
  }
}
