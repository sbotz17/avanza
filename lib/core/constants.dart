import 'package:flutter/material.dart';

const List<String> kPhaseNames = [
  'Analisi',
  'Database',
  'Backend',
  'Design',
  'Frontend',
  'Test',
  'Validazione',
];

const List<String> kKanbanColumns = [
  'backlog',
  'active',
  'blocked',
  'review',
  'validated',
  'released',
];

// Ruoli standard della squadra (menu a tendina di "Aggiungi/Modifica membro").
// Il valore salvato in Firestore (`teamMembers.role`) è il testo minuscolo
// dell'elenco; qualsiasi altro testo già salvato resta valido ("Altro…").
const List<String> kMemberRoles = [
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
];

const Map<String, String> kKanbanLabels = {
  'backlog': 'Da fare',
  'active': 'In corso',
  'blocked': 'Bloccato',
  'review': 'In test / QA',
  'validated': 'Validato',
  'released': 'Rilasciato',
};

// Light theme colors
const Color kBgLight = Color(0xFFF2F2ED);
const Color kCardLight = Color(0xFFFFFFFF);
const Color kBorderLight = Color(0xFFE4E2DA);
const Color kFgLight = Color(0xFF18181A);
const Color kFg2Light = Color(0xFF76766E);

// Dark theme colors
const Color kBgDark = Color(0xFF18181A);
const Color kCardDark = Color(0xFF24242A);
const Color kBorderDark = Color(0xFF38383E);
const Color kFgDark = Color(0xFFE8E8E2);
const Color kFg2Dark = Color(0xFF96968E);

// Status colors (light)
const Color kDoneColor = Color(0xFF1E8A3E);
const Color kDoneBg = Color(0xFFE4F5EB);
const Color kActiveColor = Color(0xFF1A6BE8);
const Color kActiveBg = Color(0xFFE6EFFE);
const Color kBlockedColor = Color(0xFFC62828);
const Color kBlockedBg = Color(0xFFFDECEA);
const Color kPendingColor = Color(0xFFADAD9A);
const Color kPendingBg = Color(0xFFF2F2ED);

// Status colors (dark)
const Color kDoneColorDark = Color(0xFF4CAF6E);
const Color kDoneBgDark = Color(0xFF192E21);
const Color kActiveColorDark = Color(0xFF5B96F6);
const Color kActiveBgDark = Color(0xFF152040);
const Color kBlockedColorDark = Color(0xFFEF5350);
const Color kBlockedBgDark = Color(0xFF2C1616);
const Color kPendingColorDark = Color(0xFF64645C);
const Color kPendingBgDark = Color(0xFF24242A);

// [T-12] Un task è "completato" quando è validato o rilasciato: da quel momento
// la chat con la squadra non è più offerta.
const List<String> kCompletedStatuses = ['validated', 'released'];

// [T-12] Chat con la squadra: lunghezza massima di un messaggio (come nelle regole Firestore).
const int kChatMaxLength = 2000;
