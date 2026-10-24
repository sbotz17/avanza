// T-19 — prove aggiuntive del tester (indipendenti da test/team_page_test.dart):
// temi veri dell'app (buildLightTheme / buildDarkTheme), schermo 320 px con il
// DIALOGO aperto, "Altro…" vuoto o con spazi, cambio di scelta nel menu,
// modifica di un membro esistente (id, tipo, attivo), ruoli con maiuscole.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/core/constants.dart';
import 'package:avanza/core/theme.dart';
import 'package:avanza/models/team_member.dart';
import 'package:avanza/pages/admin/team_page.dart';
import 'package:avanza/widgets/team_member_tile.dart';

TeamMember mem({
  String id = 'm1',
  String name = 'Anna',
  String role = '',
  double cost = 0,
  double bill = 0,
  bool active = true,
  String kind = 'agent',
}) =>
    TeamMember(
      id: id,
      ownerId: 'u1',
      name: name,
      kind: kind,
      role: role,
      costRate: cost,
      billRate: bill,
      active: active,
      createdAt: DateTime(2026, 10, 24),
    );

Future<List<TeamMember>> open(WidgetTester tester,
    {TeamMember? existing, ThemeData? theme, Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final saved = <TeamMember>[];
  await tester.pumpWidget(MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => MemberDialog(
              ownerId: 'u1',
              member: existing,
              onSave: (m) async => saved.add(m),
            ),
          ),
          child: const Text('apri'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
  return saved;
}

Future<void> chooseRole(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
  await tester.pumpAndSettle();
  final item = find.text(label);
  await tester.scrollUntilVisible(item, 50,
      scrollable: find.byType(Scrollable).last);
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('Salva'));
  await tester.pumpAndSettle();
}

void main() {
  group('Dialogo con i temi veri e schermo 320 px', () {
    for (final entry in {
      'chiaro': buildLightTheme(),
      'scuro': buildDarkTheme(),
    }.entries) {
      testWidgets('nuovo membro, "Altro…" aperto, tema ${entry.key}: nessun overflow',
          (tester) async {
        await open(tester, theme: entry.value, size: const Size(320, 640));
        await chooseRole(tester, 'Altro…');
        expect(find.text('Ruolo (testo libero)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'modifica con ruolo libero molto lungo, tema ${entry.key}: nessun overflow',
          (tester) async {
        await open(tester,
            existing: mem(
                role: 'Consulente della sicurezza sul lavoro e protezione dati'),
            theme: entry.value,
            size: const Size(320, 640));
        expect(tester.takeException(), isNull);
      });

      testWidgets('lista a 320 px con ruolo lungo e avviso, tema ${entry.key}',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: entry.value,
          home: Scaffold(
            body: TeamMembersView(onOpen: (_) {}, members: [
              mem(
                  name: 'Nome lunghissimo che non entra in una sola riga',
                  role: 'Consulente della sicurezza sul lavoro e protezione dati',
                  cost: 0,
                  bill: 99999.99),
              mem(id: 'm2', name: 'B', role: 'dba', cost: 1234567.5),
            ]),
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(find.byType(MissingCostNotice), findsOneWidget);
      });
    }
  });

  group('Ruolo: casi limite', () {
    testWidgets('"Altro…" scelto ma testo lasciato vuoto: ruolo vuoto',
        (tester) async {
      final saved = await open(tester);
      await tester.enterText(find.byType(TextField).first, 'X');
      await chooseRole(tester, 'Altro…');
      await save(tester);
      expect(saved.single.role, '');
    });

    testWidgets('"Altro…" con solo spazi: ruolo vuoto', (tester) async {
      final saved = await open(tester);
      await tester.enterText(find.byType(TextField).first, 'X');
      await chooseRole(tester, 'Altro…');
      await tester.enterText(
          find.widgetWithText(TextField, 'Ruolo (testo libero)'), '   ');
      await save(tester);
      expect(saved.single.role, '');
    });

    testWidgets('ruolo salvato solo di spazi: nessun ruolo, resta vuoto',
        (tester) async {
      final saved = await open(tester, existing: mem(role: '   '));
      expect(find.text('Scegli il ruolo'), findsOneWidget);
      await save(tester);
      expect(saved.single.role, '');
    });

    testWidgets('ruolo tutto maiuscolo ("DBA") non viene riscritto in "dba"',
        (tester) async {
      final saved = await open(tester, existing: mem(role: 'DBA'));
      expect(find.text('Altro…'), findsOneWidget);
      await save(tester);
      expect(saved.single.role, 'DBA');
    });

    testWidgets('ruolo "Sviluppatore Backend" (maiuscole) conservato',
        (tester) async {
      final saved =
          await open(tester, existing: mem(role: 'Sviluppatore Backend'));
      await save(tester);
      expect(saved.single.role, 'Sviluppatore Backend');
    });

    testWidgets('da "Altro…" con testo a un ruolo standard: salva lo standard',
        (tester) async {
      final saved = await open(tester, existing: mem(role: 'Consulente'));
      await chooseRole(tester, 'Validatore');
      expect(find.text('Ruolo (testo libero)'), findsNothing);
      await save(tester);
      expect(saved.single.role, 'validatore');
    });

    testWidgets('da ruolo standard a "Altro…": il campo parte dal ruolo attuale',
        (tester) async {
      final saved = await open(tester, existing: mem(role: 'tester'));
      await chooseRole(tester, 'Altro…');
      final field = find.widgetWithText(TextField, 'Ruolo (testo libero)');
      expect(tester.widget<TextField>(field).controller!.text, 'tester');
      await tester.enterText(field, 'collaudatore');
      await save(tester);
      expect(saved.single.role, 'collaudatore');
    });

    testWidgets('ogni ruolo standard scelto dal menu viene salvato identico',
        (tester) async {
      for (final r in kMemberRoles) {
        final saved = await open(tester);
        await tester.enterText(find.byType(TextField).first, 'N');
        await chooseRole(tester, memberRoleLabel(r));
        await save(tester);
        expect(saved.single.role, r, reason: r);
      }
    });
  });

  group('Modifica di un membro esistente', () {
    testWidgets('conserva id, proprietario, tipo, costi; cambia solo il nome',
        (tester) async {
      final saved = await open(tester,
          existing: mem(
              id: 'abc',
              name: 'Vecchio',
              role: 'dba',
              cost: 12.5,
              bill: 20,
              kind: 'person'));
      await tester.enterText(find.byType(TextField).first, 'Nuovo');
      await save(tester);
      final m = saved.single;
      expect(m.id, 'abc');
      expect(m.ownerId, 'u1');
      expect(m.name, 'Nuovo');
      expect(m.kind, 'person');
      expect(m.role, 'dba');
      expect(m.costRate, 12.5);
      expect(m.billRate, 20);
      expect(m.active, true);
    });

    testWidgets('interruttore "Attivo" spento: salva active=false',
        (tester) async {
      final saved = await open(tester, existing: mem(role: 'dba', cost: 1));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await save(tester);
      expect(saved.single.active, false);
    });

    testWidgets('costo con testo non numerico: 0 (non si blocca)',
        (tester) async {
      final saved = await open(tester);
      await tester.enterText(find.byType(TextField).first, 'N');
      await tester.enterText(
          find.widgetWithText(TextField, 'Costo orario interno (€/h)'), 'abc');
      await save(tester);
      expect(saved.single.costRate, 0);
    });

    testWidgets('errore di salvataggio: il dialogo resta aperto con messaggio',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => MemberDialog(
                  ownerId: 'u1',
                  onSave: (m) async => throw Exception('rete assente'),
                ),
              ),
              child: const Text('apri'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'N');
      await save(tester);
      expect(find.text('Nuovo membro'), findsOneWidget);
      expect(find.textContaining('rete assente'), findsOneWidget);
    });
  });

  group('Lista: avviso e costo non impostato', () {
    Future<void> show(WidgetTester tester, List<TeamMember> ms) =>
        tester.pumpWidget(MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: TeamMembersView(members: ms, onOpen: (_) {})),
        ));

    testWidgets('costo 0 attivo + 0 disattivo: avviso conta solo gli attivi',
        (tester) async {
      await show(tester, [
        mem(id: 'a', name: 'A', cost: 0),
        mem(id: 'b', name: 'B', cost: 0, active: false),
        mem(id: 'c', name: 'C', cost: 5),
      ]);
      expect(find.textContaining('1 membro attivo ha il costo'), findsOneWidget);
      expect(find.textContaining('Costo non impostato'), findsNWidgets(2));
    });

    testWidgets('costo 0,01: impostato, nessun avviso', (tester) async {
      await show(tester, [mem(cost: 0.01)]);
      expect(find.byType(MissingCostNotice), findsNothing);
      expect(find.textContaining('Costo non impostato'), findsNothing);
    });

    testWidgets('ruolo di soli spazi in lista: "ruolo non impostato"',
        (tester) async {
      await show(tester, [mem(role: '   ', cost: 3)]);
      expect(find.text('Agente · ruolo non impostato'), findsOneWidget);
    });

    testWidgets('avviso sempre in cima alla lista', (tester) async {
      await show(tester, [mem(name: 'Zeta', cost: 0)]);
      final notice = tester.getTopLeft(find.byType(MissingCostNotice)).dy;
      final tile = tester.getTopLeft(find.byType(TeamMemberTile)).dy;
      expect(notice < tile, isTrue);
    });

    testWidgets('molti membri (13) con costo 0: un solo avviso al plurale',
        (tester) async {
      await show(tester, [
        for (var i = 0; i < 13; i++)
          mem(id: 'm$i', name: 'Agente $i', role: kMemberRoles[i], cost: 0),
      ]);
      expect(find.byType(MissingCostNotice), findsOneWidget);
      expect(find.textContaining('13 membri attivi hanno'), findsOneWidget);
    });
  });
}
