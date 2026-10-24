// T-19: pagina Squadra — menu a tendina "Ruolo", messaggi d'aiuto, riga membro.
// Niente Firebase: si provano i widget (MemberDialog, TeamMembersView,
// TeamMemberTile) con dati e funzione di salvataggio finti.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avanza/core/constants.dart';
import 'package:avanza/models/team_member.dart';
import 'package:avanza/pages/admin/team_page.dart';
import 'package:avanza/widgets/team_member_tile.dart';

TeamMember member({
  String name = 'Anna',
  String role = '',
  double cost = 0,
  double bill = 0,
  bool active = true,
  String kind = 'agent',
}) =>
    TeamMember(
      id: 'm1',
      ownerId: 'u1',
      name: name,
      kind: kind,
      role: role,
      costRate: cost,
      billRate: bill,
      active: active,
      createdAt: DateTime(2026, 10, 24),
    );

/// Apre il dialogo dentro un'app minima e restituisce i membri "salvati".
Future<List<TeamMember>> openDialog(WidgetTester tester,
    {TeamMember? existing}) async {
  final saved = <TeamMember>[];
  await tester.pumpWidget(MaterialApp(
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

Finder get roleDropdown => find.byType(DropdownButtonFormField<String>).at(1);

Future<void> openRoleMenu(WidgetTester tester) async {
  await tester.tap(roleDropdown);
  await tester.pumpAndSettle();
}

Future<void> pickRole(WidgetTester tester, String label) async {
  await openRoleMenu(tester);
  final item = find.text(label);
  await tester.scrollUntilVisible(item, 50,
      scrollable: find.byType(Scrollable).last);
  // Un po' oltre, così la voce non resta sul bordo del menu.
  await tester.drag(find.byType(Scrollable).last, const Offset(0, -60));
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Salva'));
  await tester.pumpAndSettle();
}

void main() {
  group('Elenco ruoli standard', () {
    test('contiene i 13 ruoli della squadra, senza doppioni', () {
      expect(kMemberRoles.length, 13);
      expect(kMemberRoles.toSet().length, 13);
      for (final r in [
        'analista',
        'architetto',
        'dba',
        'designer',
        'sviluppatore backend',
        'sviluppatore frontend',
        'tester',
        'validatore',
        'gestore ritorni',
        'risolutore bug',
        'guardiano produzione',
        'redattore manuale',
        'marketing',
      ]) {
        expect(kMemberRoles, contains(r));
      }
    });

    test('memberRoleLabel: maiuscola iniziale solo per la visualizzazione', () {
      expect(memberRoleLabel('sviluppatore backend'), 'Sviluppatore backend');
      expect(memberRoleLabel('dba'), 'Dba');
      expect(memberRoleLabel(''), '');
    });
  });

  group('MemberDialog - menu Ruolo', () {
    testWidgets('mostra tutti i ruoli standard e "Altro…"', (tester) async {
      await openDialog(tester);
      expect(find.text('Ruolo'), findsOneWidget);
      await openRoleMenu(tester);
      // Il menu è una lista scorrevole: si scorre fino a vedere ogni voce
      // (la copia nascosta nel campo non conta: è fuori vista).
      for (final r in [...kMemberRoles.map(memberRoleLabel), 'Altro…']) {
        await tester.scrollUntilVisible(find.text(r), 50,
            scrollable: find.byType(Scrollable).last);
        expect(find.text(r), findsOneWidget, reason: r);
      }
    });

    testWidgets('scegliere un ruolo standard lo salva in minuscolo',
        (tester) async {
      final saved = await openDialog(tester);
      await tester.enterText(find.byType(TextField).first, 'Test Agent');
      await pickRole(tester, 'Tester');
      // Con un ruolo standard non compare il campo di testo libero.
      expect(find.text('Ruolo (testo libero)'), findsNothing);
      await tapSave(tester);
      expect(saved.length, 1);
      expect(saved.single.role, 'tester');
      expect(saved.single.name, 'Test Agent');
    });

    testWidgets('"Altro…" mostra il campo libero e salva il testo scritto',
        (tester) async {
      final saved = await openDialog(tester);
      await tester.enterText(find.byType(TextField).first, 'Mario');
      await pickRole(tester, 'Altro…');
      expect(find.text('Ruolo (testo libero)'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, 'Ruolo (testo libero)'),
          'consulente legale');
      await tapSave(tester);
      expect(saved.single.role, 'consulente legale');
    });

    testWidgets('nuovo membro senza ruolo scelto: ruolo vuoto', (tester) async {
      final saved = await openDialog(tester);
      await tester.enterText(find.byType(TextField).first, 'Senza ruolo');
      expect(find.text('Scegli il ruolo'), findsOneWidget);
      await tapSave(tester);
      expect(saved.single.role, '');
    });

    testWidgets('ruolo standard già salvato: preselezionato, resta invariato',
        (tester) async {
      final saved = await openDialog(tester,
          existing: member(role: 'sviluppatore backend', cost: 40, bill: 70));
      expect(find.text('Sviluppatore backend'), findsOneWidget);
      expect(find.text('Ruolo (testo libero)'), findsNothing);
      await tapSave(tester);
      expect(saved.single.role, 'sviluppatore backend');
      expect(saved.single.costRate, 40);
      expect(saved.single.billRate, 70);
    });

    testWidgets(
        'ruolo non in elenco: preselezionato come "Altro…" con il suo testo, '
        'mai perso', (tester) async {
      final saved = await openDialog(tester,
          existing: member(role: 'Consulente Sicurezza'));
      expect(find.text('Altro…'), findsOneWidget);
      expect(find.text('Ruolo (testo libero)'), findsOneWidget);
      expect(find.text('Consulente Sicurezza'), findsOneWidget);
      await tapSave(tester);
      expect(saved.single.role, 'Consulente Sicurezza');
    });

    testWidgets('ruolo salvato con maiuscola ("Tester") non viene riscritto',
        (tester) async {
      final saved = await openDialog(tester, existing: member(role: 'Tester'));
      expect(find.text('Altro…'), findsOneWidget);
      await tapSave(tester);
      expect(saved.single.role, 'Tester');
    });

    testWidgets('ruolo vuoto già salvato resta vuoto', (tester) async {
      final saved = await openDialog(tester, existing: member(role: ''));
      expect(find.text('Scegli il ruolo'), findsOneWidget);
      await tapSave(tester);
      expect(saved.single.role, '');
    });

    testWidgets('costo e vendita con la virgola vengono letti', (tester) async {
      final saved = await openDialog(tester);
      await tester.enterText(find.byType(TextField).first, 'Costi');
      await tester.enterText(
          find.widgetWithText(TextField, 'Costo orario interno (€/h)'), '35,5');
      await tester.enterText(
          find.widgetWithText(TextField, 'Tariffa di vendita oraria (€/h)'),
          '60');
      await tapSave(tester);
      expect(saved.single.costRate, 35.5);
      expect(saved.single.billRate, 60);
    });

    testWidgets('nome vuoto: errore e nessun salvataggio', (tester) async {
      final saved = await openDialog(tester);
      await tapSave(tester);
      expect(find.text('Il nome è obbligatorio.'), findsOneWidget);
      expect(saved, isEmpty);
    });
  });

  group('TeamMembersView / TeamMemberTile', () {
    Future<void> show(WidgetTester tester, List<TeamMember> members,
        {void Function(TeamMember)? onOpen}) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TeamMembersView(members: members, onOpen: onOpen ?? (_) {}),
        ),
      ));
    }

    testWidgets('nessun membro: messaggio d\'aiuto', (tester) async {
      await show(tester, []);
      expect(find.text('Nessun membro nella squadra'), findsOneWidget);
      expect(find.textContaining('Aggiungi membro'), findsOneWidget);
      expect(find.byType(TeamMemberTile), findsNothing);
    });

    testWidgets('mostra ruolo, costo e vendita sulla riga', (tester) async {
      await show(tester, [
        member(
            name: 'Bruno', role: 'sviluppatore backend', cost: 40, bill: 70.5),
      ]);
      expect(find.text('Bruno'), findsOneWidget);
      expect(find.text('Agente · Sviluppatore backend'), findsOneWidget);
      expect(find.textContaining('Costo 40,00'), findsOneWidget);
      expect(find.textContaining('Vendita 70,50'), findsOneWidget);
      expect(find.textContaining('Costo non impostato'), findsNothing);
      // Tutti i costi impostati: nessun avviso in cima.
      expect(find.byType(MissingCostNotice), findsNothing);
    });

    testWidgets('costo 0: "Costo non impostato" sulla riga e avviso in cima',
        (tester) async {
      await show(tester, [
        member(name: 'Carla', role: 'dba', cost: 0, bill: 50),
        member(name: 'Dario', role: 'tester', cost: 0),
        member(name: 'Elena', role: 'analista', cost: 30),
      ]);
      expect(find.byType(MissingCostNotice), findsOneWidget);
      expect(find.textContaining('2 membri attivi hanno il costo orario'),
          findsOneWidget);
      expect(find.textContaining('Costo non impostato'), findsNWidgets(2));
    });

    testWidgets('un solo membro senza costo: testo al singolare',
        (tester) async {
      await show(tester, [member(role: 'dba', cost: 0)]);
      expect(find.textContaining('1 membro attivo ha il costo orario'),
          findsOneWidget);
    });

    testWidgets('membro non attivo con costo 0: riga segnalata, nessun avviso',
        (tester) async {
      await show(tester, [member(role: 'dba', cost: 0, active: false)]);
      expect(find.byType(MissingCostNotice), findsNothing);
      expect(find.textContaining('Costo non impostato'), findsOneWidget);
      expect(find.text('Non attivo'), findsOneWidget);
    });

    testWidgets('senza ruolo: "ruolo non impostato"', (tester) async {
      await show(tester, [member(role: '', cost: 10)]);
      expect(find.text('Agente · ruolo non impostato'), findsOneWidget);
    });

    testWidgets('ruolo libero esistente mostrato com\'è', (tester) async {
      await show(tester, [
        member(role: 'Consulente Sicurezza', cost: 10, kind: 'person'),
      ]);
      expect(find.text('Persona · Consulente Sicurezza'), findsOneWidget);
    });

    testWidgets('toccare la riga apre il membro', (tester) async {
      TeamMember? opened;
      await show(tester, [member(name: 'Fabio', cost: 10)],
          onOpen: (m) => opened = m);
      await tester.tap(find.text('Fabio'));
      expect(opened?.name, 'Fabio');
    });

    testWidgets('schermo stretto e tema scuro: nessun overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: TeamMembersView(members: [
            member(
                name: 'Nome molto lungo per uno schermo piccolo',
                role: 'guardiano produzione',
                cost: 0,
                bill: 1234.5),
          ], onOpen: (_) {}),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
