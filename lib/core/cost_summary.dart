import '../models/team_member.dart';

/// Nomi dei membri attivi che non hanno ancora un costo orario interno.
/// Un costo a 0 non valorizza la spesa per operatore: il report lo deve dire.
bool memberCostMissing(TeamMember m) => m.costRate <= 0;

List<String> missingCostMemberNames(Iterable<TeamMember> members) => members
    .where((m) => m.active && memberCostMissing(m))
    .map((m) => m.name)
    .toList();

/// Testo del costo di un membro nel report: se ha lavorato ma la tariffa è 0,
/// non si mostra un falso "€ 0,00" ma "costo non impostato (tariffa 0)".
String? memberCostNotSetLabel(double hours, double cost) =>
    hours > 0 && cost <= 0 ? 'costo non impostato (tariffa 0)' : null;
