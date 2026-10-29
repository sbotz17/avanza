import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../models/team_member.dart';

/// Testo del ruolo da mostrare: prima lettera maiuscola ("sviluppatore backend"
/// -> "Sviluppatore backend"). Solo per la visualizzazione: il valore salvato
/// non cambia.
String memberRoleLabel(String role) {
  final r = role.trim();
  if (r.isEmpty) return r;
  return r[0].toUpperCase() + r.substring(1);
}

/// Il costo orario interno è "non impostato" quando vale 0 (valore di
/// partenza dei membri creati dagli script o con il campo lasciato vuoto).
bool memberCostNotSet(TeamMember m) => m.costRate <= 0;

/// Riga di un membro nella pagina Squadra: nome, tipo e ruolo ben visibili,
/// costo e vendita orari sulla stessa riga; avviso quando il costo è 0.
class TeamMemberTile extends StatelessWidget {
  final TeamMember member;
  final VoidCallback? onTap;

  const TeamMemberTile({super.key, required this.member, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? kFgDark : kFgLight;
    final fg2 = isDark ? kFg2Dark : kFg2Light;
    final warn = isDark ? kBlockedColorDark : kBlockedColor;
    final eur = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final m = member;
    final kind = kMemberKindLabels[m.kind] ?? m.kind;
    final hasRole = m.role.trim().isNotEmpty;
    final costMissing = memberCostNotSet(m);

    // Material (non un Container colorato) così il tocco sulla riga si vede.
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? kCardDark : kCardLight,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? kBorderDark : kBorderLight),
        ),
        child: ListTile(
          onTap: onTap,
          isThreeLine: true,
          title: Text(
            m.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: m.active ? null : TextDecoration.lineThrough,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                hasRole
                    ? '$kind · ${memberRoleLabel(m.role)}'
                    : '$kind · ruolo non impostato',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasRole ? FontWeight.w600 : FontWeight.w400,
                  fontStyle: hasRole ? FontStyle.normal : FontStyle.italic,
                  color: hasRole ? fg : fg2,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 12, color: fg2),
                  children: [
                    if (costMissing)
                      TextSpan(
                        text: 'Costo non impostato',
                        style: TextStyle(
                          color: warn,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      TextSpan(text: 'Costo ${eur.format(m.costRate)}/h'),
                    TextSpan(text: ' · Vendita ${eur.format(m.billRate)}/h'),
                  ],
                ),
              ),
            ],
          ),
          trailing: m.active
              ? null
              : Text('Non attivo', style: TextStyle(fontSize: 11, color: fg2)),
        ),
      ),
    );
  }
}
