# Squadra: ruoli e costi orari (manuale utente, solo admin)

La pagina **Squadra** elenca gli agenti e le persone che lavorano ai progetti, con il loro **ruolo**, il **costo orario interno** e la **tariffa di vendita oraria**.

- **Aggiungere un membro:** tocca "Aggiungi membro", scrivi il nome, scegli il tipo (Agente o Persona) e il **ruolo dal menu a tendina** (analista, architetto, dba, designer, sviluppatore backend, sviluppatore frontend, tester, validatore, gestore ritorni, risolutore bug, guardiano produzione, redattore manuale, marketing). Se il ruolo che cerchi non c'è, scegli **Altro…** e scrivilo a mano.
- **Modificare un membro:** tocca la riga. Un ruolo già salvato non viene mai perso: se non è nell'elenco compare sotto "Altro…" con il suo testo.
- **Costo orario:** inserisci quanto costa un'ora di quel membro. Se il costo è 0 la riga mostra "Costo non impostato" e in cima compare un avviso. Il costo viene copiato nelle ore **al momento della registrazione**: impostarlo ora non cambia le ore già registrate a costo 0.
- **Non attivo:** un membro non attivo non compare nel dialogo "Registra ore".
- Se non vedi nessun membro, la squadra è intestata a un altro account: chiedi alla squadra di copiarla nel tuo (azione `copia-squadra`).
