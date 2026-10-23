# Protocollo: ogni richiesta è un task in Avanza

Valido per **ogni progetto** e per **ogni strumento** (Claude Code, OpenCode, altri) ogni volta che Andrea usa la squadra.
Avanza è il registro di tutto il lavoro: stato dei task, ore, costi e produttività dipendono da questo protocollo.

## Regole
1. **Prima di lavorare**, ogni richiesta (sviluppo, correzione, ritorno, urgenza) diventa un **task** nel progetto giusto di Avanza.
2. Il task riceve un codice `T-N`. Il **nome del ramo** e il **titolo della pull request** contengono quel codice
   (es. `feature/T-12-filtro-clienti`, `fix/T-13-spinner`). Per i ritorni resta anche il riferimento `R-n`.
3. **Non cambiare a mano lo stato**: lo aggiorna da solo il webhook GitHub (ramo creato = in corso, PR aperta = nota,
   PR unita = in test, PR approvata = validato). Se serve altro, il coordinatore aggiorna il task.
4. **A fine di ogni fase** la squadra dichiara le **ore** per ogni membro che ha lavorato (agente o persona), con la fase e una nota.
   Sono **stime oneste, non tempi misurati**: lo si scrive nella nota.
5. Nella nota delle ore scrivi anche lo **strumento** usato (Claude Code, OpenCode, ...).
6. Se non riesci a creare il task o a dichiarare le ore (workflow non raggiungibile, permessi), **non bloccare il lavoro**:
   scrivilo in `docs/progetto/registro-decisioni.md` del progetto e avvisa Andrea nel resoconto. Mai inventare ore o codici.
7. I **progetti** sono quelli registrati in Avanza (uno per repository, collegato dall'indirizzo GitHub):
   Avanza `https://github.com/sbotz17/avanza`, Volty `https://github.com/sbotz17/volty-flutter`.
   Un progetto nuovo si crea con l'azione `crea-progetto`.

## Come si fa (workflow "Registra ore squadra" del repository `sbotz17/avanza`, ramo `main`)
Il workflow scrive nel database di produzione con le credenziali della CI: gli agenti **non** hanno né chiavi né accesso diretto.

### Creare uno o più task (azione `importa-task`)
Ingressi: `action=importa-task`, `github_url` del progetto, `tasks_json` = elenco JSON:
```json
[{"title":"Filtro clienti","description":"...","clientRequest":"testo della richiesta di Andrea",
  "status":"active","phases":{"Analisi":"active"},"notes":[{"type":"info","text":"Strumento: Claude Code"}]}]
```
- `status`: `backlog`, `active`, `blocked`, `review`, `validated`, `released`. Per un lavoro che parte ora usa `active`.
- `phases`: mappa fase -> `done`, `active`, `pending`, `skip`, `blocked` (fasi: Analisi, Database, Backend, Design, Frontend, Test, Validazione).
- Non duplica: un titolo già presente viene saltato. Il log stampa i codici assegnati (`T-12 Filtro clienti`).

### Dichiarare le ore (azione `ore`)
Ingressi: `action=ore`, `github_url`, `task_code` (es. `T-12`), `phase`, `member` (es. `sviluppatore-backend`), `hours`, `note`.
Esempio nota: `Stima onesta, non misurata. Strumento: OpenCode`.
I membri della squadra sono in Avanza (pagina Costi > Squadra); azione `membro` per aggiungerne.

### Esempi di chiamata
- **Claude Code con strumenti GitHub (MCP)**: `actions_run_trigger` con `method=run_workflow`, `owner=sbotz17`, `repo=avanza`,
  `workflow_id=registra-ore.yml`, `ref=main`, `inputs={...}`.
- **OpenCode o terminale con `gh` autenticato**:
  `gh workflow run registra-ore.yml -R sbotz17/avanza --ref main -f action=importa-task -f github_url=https://github.com/sbotz17/volty-flutter -f tasks_json='[...]'`
- Per leggere i codici assegnati: apri il run in GitHub Actions (log del passo "Registra") oppure usa l'azione `stato`.

## Cosa aggiorna Avanza da solo
- Stato e note del task dal webhook GitHub (`githubWebhook`) quando il ramo o la PR contiene il codice.
- Report di preventivo, costo reale, da fatturare, margine e produttività dalle ore dichiarate (pagina Costi).

## Perché
Andrea vede in un posto solo cosa è stato chiesto, a che punto è, quanto è costato e quanto è produttivo ogni membro della squadra,
su tutti i progetti e con qualunque strumento.
