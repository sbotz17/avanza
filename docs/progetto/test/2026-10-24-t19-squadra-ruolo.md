# Report di test — T-19: pagina Squadra, ruolo a tendina e costi orari

- **Data**: 2026-10-24
- **Tester**: tester (Claude Code), verifica indipendente
- **Oggetto**: ramo `origin/feature/T-19-squadra-ruolo`, commit `f81b6d2` (diff: `git diff origin/staging...origin/feature/T-19-squadra-ruolo`)
- **Ambiente**: Flutter 3.47.8 stable (Dart 3.13.7) scaricato da zero in una cartella temporanea; Chromium headless con Playwright. Nessun accesso a Firebase né a dati reali.
- **Fonte dei criteri**: la richiesta di Andrea come riportata nell'incarico (il file `requisiti.md` non contiene una sezione T-19).

## Esito: SUPERATO

Tutti i 7 criteri sono OK nei limiti dichiarati in fondo (login e Firestore reali non provati). Nessun difetto bloccante, alto o medio. Tre osservazioni di gravità bassa.

## Tabella criteri

| # | Criterio | Come verificato | Esito | Evidenza |
|---|---|---|---|---|
| 1 | Menu Ruolo con 13 ruoli + "Altro…" | Lettura del codice (`kMemberRoles`, `MemberDialog`); test automatico che confronta i 13 valori; prova nel browser: aperto il menu e letto l'elenco dalle voci (`menuitem`) | OK | Browser (320 px, chiaro e scuro): Analista, Architetto, Dba, Designer, Sviluppatore backend, Sviluppatore frontend, Tester, Validatore, Gestore ritorni, Risolutore bug, Guardiano produzione, Redattore manuale, Marketing, Altro… (14 voci). Screenshot `shot-DARK320-menu-ruolo.png`. Test: `team_page_test.dart` "contiene i 13 ruoli" e "mostra tutti i ruoli standard e Altro…"; mio test "ogni ruolo standard scelto dal menu viene salvato identico" (13 ruoli, salvataggio minuscolo identico all'elenco) |
| 2 | Ruolo già salvato fuori elenco o con maiuscole non perso né riscritto; ruolo vuoto resta vuoto | Test widget + prova nel browser sul dialogo di modifica | OK | Browser: membro con ruolo "Tester" -> dialogo mostra "Altro…" con testo "Tester" -> Salva -> `SALVATO\|Tester\|agent\|Tester\|0\|0\|true` (invariato, in chiaro e scuro). Membro senza ruolo -> "Scegli il ruolo" -> Salva -> ruolo vuoto. Test miei: "DBA", "Sviluppatore Backend", ruolo di soli spazi (-> vuoto), "Altro…" vuoto o con spazi (-> vuoto), passaggio Altro->standard e standard->Altro (il campo parte dal ruolo attuale). Mutazioni M1, M2, M10 fanno fallire i test |
| 3 | Lista: ruolo visibile, costo e vendita, "Costo non impostato" se costo 0, avviso in cima con attivi a costo 0, messaggio a lista vuota | Screenshot nel browser con 6 membri finti (costo 0 attivi, con costo, senza ruolo, disattivato, nome lungo) e con lista vuota; test widget | OK | `shot-light-desktop-lista.png`: avviso rosso "3 membri attivi hanno il costo orario non impostato…" in cima; riga "Agente · Analista" in grassetto, "Costo non impostato · Vendita 0,00 €/h" (rosso sul costo), "Costo 45,50 €/h · Vendita 90,00 €/h"; senza ruolo -> "ruolo non impostato" in corsivo; disattivato: nome barrato, "Non attivo", non conta nell'avviso. `shot-empty-mobile-lista.png`: "Nessun membro nella squadra" con spiegazione. Test miei: conteggio solo attivi, singolare/plurale (1 e 13), costo 0,01 = impostato, avviso sopra la prima riga |
| 4 | Salvataggio corretto di nome, tipo, ruolo, costo, vendita, attivo (virgola inclusa) | Browser (dati visti nell'esito del salvataggio finto) + test widget | OK | Browser: nuovo "Prova A", Tester, costo "35,5", vendita "60" -> `SALVATO\|Prova A\|agent\|tester\|35.5\|60\|true`. Nuovo con "Altro…" "Consulente Legale" -> salvato identico. Test miei: modifica conserva id, ownerId, tipo `person`, ruolo, costi; interruttore Attivo spento -> `active=false`; testo non numerico -> 0; errore di rete nel salvataggio -> dialogo aperto con messaggio. Mutazioni M4, M11, M15, M16 fanno fallire i test |
| 5 | Nessuna modifica a modelli, FirestoreService, regole, indici | `git diff --stat origin/staging...origin/feature/T-19-squadra-ruolo -- pubspec.lock pubspec.yaml lib/models lib/services firestore.rules firestore.indexes.json` | OK | Output vuoto. File toccati: catalogo.md, diario.md, log-attivita.md, `lib/core/constants.dart`, `team_page.dart`, nuovo `team_member_tile.dart`, `test/team_page_test.dart`. `pubspec.lock` non nel commit (la mia `pub get` lo ha modificato solo in locale, non committato). `showMemberDialog` passa `service.saveTeamMember` come `onSave`: la scrittura passa ancora solo da `FirestoreService`. Unico uso di `showMemberDialog`/`MemberDialog` nel codice: `team_page.dart` |
| 6 | Nessun duplicato evitabile, `catalogo.md` aggiornato | Ricerca nel codice di widget, avvisi, liste di ruoli e stati vuoti simili; lettura del diff del catalogo | OK | Riusati `EmptyState`, i colori `kBlocked*`, `kMemberKindLabels`. Nessun altro widget di avviso o elenco di ruoli esistente (grep). Catalogo: voci `TeamMemberTile/memberRoleLabel/memberCostNotSet`, `TeamPage/TeamMembersView/MissingCostNotice/MemberDialog`, `kMemberRoles`, con percorsi. Nota: `MissingCostNotice` (contenitore con icona e colore "bloccato") è un pattern vicino a `NoticeBox`-simili in altre pagine, ma non esiste un widget condiviso equivalente: non è un duplicato evitabile |
| 7 | Tema scuro/chiaro e schermo stretto 320 px senza overflow | Browser 320x640 e 1200x800 in chiaro e scuro (temi veri `buildLightTheme/buildDarkTheme`); test widget con i temi veri e 320 px, anche con il dialogo aperto e un ruolo molto lungo | OK | Screenshot `shot-dark-mobile320-lista.png`, `shot-light-mobile320-lista.png`, `shot-DARK320-*`, `shot-LIGHT320-*`: nessun overflow visibile; errori di pagina nella console: nessuno. 6 test miei (lista e dialogo, chiaro e scuro, nome e ruolo lunghissimi, importi grandi): `takeException()` nullo |

## Esecuzioni

| Comando | Risultato |
|---|---|
| `flutter pub get` | OK (modifica solo `pubspec.lock` locale, non committata) |
| `flutter analyze` | 6 `info` (tutti preesistenti: 3 `deprecated_member_use` in `edit_task_page.dart`, 3 in `test/auth_provider_test.dart`), nessun warning né errore. Identico dopo l'aggiunta dei miei test |
| `flutter test` (ramo dello sviluppatore) | 58 test verdi, come atteso |
| `flutter test` (con i miei 23 test aggiunti) | 81 test verdi |
| `flutter build web --release --pwa-strategy=none` | OK (`Built build/web`) |
| `npm run build` / `npm test` in `functions/` | Non eseguiti: nessuna modifica in `functions/` nel diff |

## Prova nel browser (come è stata fatta e perché non è la pagina vera)

Senza login né Firestore la pagina `/team` vera non è raggiungibile. Ho costruito un piccolo harness locale (file temporaneo, **non** committato e poi cancellato) che monta gli stessi widget del ramo (`TeamMembersView`, `MemberDialog`) con i temi veri dell'app, dati finti e una funzione di salvataggio finta che scrive l'esito a schermo. L'ho compilato in release (`flutter build web`), servito con un web server locale e comandato con Playwright (accessibilità attivata per leggere le voci). CanvasKit è stato servito dal build locale perché il CDN non è raggiungibile dal proxy. Percorso della build: `/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/harness-web`; script e screenshot nella stessa cartella `scratchpad` (`pw1.js`, `pw3.js`, `shot-*.png`).

Flussi provati in chiaro e scuro, a 320 px: A) nuovo membro con ruolo "Tester", costo "35,5", vendita "60"; B) nuovo con "Altro…" e testo libero; C) modifica di un membro con ruolo "Tester" (maiuscola); D) modifica di un membro senza ruolo. Esiti riportati nel criterio 2 e 4.

## Controllo di mutazione (16 mutazioni sul codice, ripristinato dopo ogni prova)

Eseguite con `sed` sul codice del ramo, ognuna con entrambe le suite (la mia e quella dello sviluppatore). Tutte le 16 sono state "uccise" (almeno un test fallisce); `git status` finale mostra `lib/` pulito.

| Mutazione | Fallisce nella suite dello sviluppatore | Fallisce nella mia |
|---|---|---|
| M1 preselezione senza distinzione maiuscole (riscrive "Tester") | sì | sì |
| M2 ruolo fuori elenco perso (preselezione nulla) | sì | sì |
| M3 "Altro…" salva sempre vuoto | sì | sì |
| M4 virgola decimale non gestita | sì | no |
| M5 avviso conta anche i non attivi | sì | sì |
| M6 avviso mai mostrato | sì | sì |
| M7 costo 0 non più "non impostato" | sì | sì |
| M8 manca un ruolo standard | sì | sì |
| M9 manca "Altro…" nel menu | sì | sì |
| M10 ruolo vuoto salvato con testo residuo | sì | sì |
| M11 il tipo salva il ruolo | **no** | sì |
| M12 ruolo di soli spazi considerato impostato in lista | **no** | sì |
| M13 niente messaggio a lista vuota | sì | no |
| M14 etichetta ruolo non capitalizzata | sì | sì |
| M15 vendita non salvata | sì | sì |
| M16 "attivo" sempre vero | **no** | sì |

Lacune della suite dello sviluppatore (M11, M12, M16: tipo, ruolo di soli spazi, interruttore Attivo): coperte dai miei test, che propongo di tenere (file `test/team_page_tester_test.dart`, 23 casi, sul ramo `test/T-19-report`).

## Difetti trovati

Nessun difetto bloccante, alto o medio. Osservazioni di gravità **bassa** (nessuna blocca il rilascio):

1. **Bassa — "Dba" in lista.** `memberRoleLabel` mette solo la prima lettera maiuscola: il ruolo `dba` si vede "Dba" (sigla). Solo estetico. Sviluppatore competente: sviluppatore-frontend.
2. **Bassa — etichette dei campi tagliate a 320 px.** Nel dialogo "Costo orario interno (€/h)" e "Tariffa di vendita oraria (€/h)" appaiono con i puntini ("Costo orario inte…") sullo schermo stretto. Le etichette non sono cambiate rispetto a prima (preesistente), non c'è overflow. Sviluppatore competente: sviluppatore-frontend / designer-frontend.
3. **Bassa — spazi ai bordi del ruolo.** Un ruolo salvato con spazi iniziali o finali (es. "Tester ") viene risalvato senza spazi, perché il valore passa da `trim()`. Era già così nel codice precedente (non è una regressione) e il ruolo non viene perso; lo segnalo perché il criterio 2 dice "non riscritto" per il testo. Sviluppatore competente: sviluppatore-frontend (eventuale).

Altre note, non difetti:
- Il ruolo "designer" dell'elenco non coincide col nome dell'agente (`designer-frontend`); se i dati reali hanno "designer frontend" verranno preselezionati come "Altro…" e conservati (comportamento sicuro).
- I ruoli realmente salvati in Firestore non sono stati letti: non so quanti dei 12 agenti reali coincidano con l'elenco; la protezione "Altro…" li conserva comunque.

## Cosa NON ho potuto verificare

- Login reale, pagina `/team` vera dietro il router, `StreamBuilder` su Firestore, `teamMembersStream` e salvataggio reale con `FirestoreService.saveTeamMember` (provati solo con dati e salvataggio finti).
- Regole di sicurezza e indici: non toccati dal ramo (diff vuoto), quindi non ripetuti; test dell'emulatore Firebase non eseguiti.
- Il sito pubblicato (anteprima/test) e la CI su GitHub: non verificati; ho eseguito solo gli stessi comandi in locale.
- Browser diversi da Chromium, dispositivi reali, tastiera su telefono (la virgola decimale è stata provata digitando da tastiera in Chromium).
- Compatibilità con le versioni precedenti dell'app: il ramo non cambia modelli né dati; non c'è una versione installabile (solo web).
- Duplicati: controllo fatto con ricerca nel codice e nel catalogo, non con `/catalogo` completo.

## File

- Report: `/home/user/avanza/.claude/worktrees/agent-acbedc3b999ca22b0/docs/progetto/test/2026-10-24-t19-squadra-ruolo.md`
- Test aggiuntivi del tester: `/home/user/avanza/.claude/worktrees/agent-acbedc3b999ca22b0/test/team_page_tester_test.dart`
- Screenshot e script: `/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/` (`shot-*.png`, `pw1.js`, `pw3.js`, `mut.sh`)
