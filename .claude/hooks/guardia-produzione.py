#!/usr/bin/env python3
"""Guardia di sicurezza della squadra (hook PreToolUse di Claude Code): exit 2 = azione bloccata, il messaggio arriva a Claude.

Protegge:
 1. la leva di Andrea (BLOCCO-SQUADRA.md);
 2. le regole della squadra (hook, impostazioni, CLAUDE.md, CI, zone protette, script, agenti, comandi): gli agenti non le modificano;
 3. i dati e la storia Git (comandi distruttivi);
 4. i backup (mai cancellati);
 5. la produzione (niente scritture senza backup recente, niente cancellazioni, niente push verso la produzione);
 6. le decisioni di Andrea su GitHub (approvazioni, protezioni, segreti: mai dagli agenti).
E' una rete di sicurezza contro errori e abusi evidenti, non l'unica difesa: le difese decisive sono su GitHub
(protezione dei rami, CODEOWNERS, ambienti con revisore) e nella separazione delle credenziali.
"""
import json, os, re, sys, time


def esci(msg):
    sys.stderr.write(msg + "\n")
    sys.exit(2)


def blocca(msg):
    esci("BLOCCATO dalla guardia di sicurezza: " + msg + "\n"
         "Questo e' un LIMITE INVALICABILE: non va aggirato con comandi equivalenti ne' con altri strumenti. "
         "Non e' un'attesa di permesso: scrivi la decisione in sospeso in docs/progetto/registro-decisioni.md "
         "(cosa volevi fare, perche', rischi, alternative sicure), avvisa Andrea e prosegui con il resto del lavoro "
         "usando una strada che non violi il limite. Vedi Autonomia e limiti invalicabili in CLAUDE.md.")


try:
    data = json.load(sys.stdin)
except Exception:
    esci("BLOCCATO: la guardia non ha ricevuto dati leggibili. Per sicurezza l'azione non viene eseguita.")

tool = data.get("tool_name", "Bash")
tin = data.get("tool_input") or {}
cmd = (tin.get("command") or "") if tool == "Bash" else ""
cwd = os.path.abspath(data.get("cwd") or os.getcwd())
HOME = os.path.expanduser("~")
SCRIVE_FILE = tool in ("Write", "Edit", "MultiEdit", "NotebookEdit")


def radice_progetto(d):
    """Cartella del progetto: la prima che contiene .claude/ o .git risalendo da d."""
    x = d
    while True:
        if os.path.isdir(os.path.join(x, ".claude")) or os.path.exists(os.path.join(x, ".git")):
            return x
        if os.path.dirname(x) == x:
            return d
        x = os.path.dirname(x)


ROOT = os.environ.get("CLAUDE_PROJECT_DIR") or radice_progetto(cwd)

# ---------------- 1. BLOCCO DI EMERGENZA (leva di Andrea) ----------------
def blocco_attivo():
    cand = [os.path.join(HOME, ".claude", "BLOCCO-SQUADRA.md")]
    d = cwd
    while True:
        cand.append(os.path.join(d, "BLOCCO-SQUADRA.md"))
        if os.path.dirname(d) == d:
            break
        d = os.path.dirname(d)
    for f in cand:
        try:
            with open(f, encoding="utf-8") as fh:
                prima = next((r.strip() for r in fh if r.strip()), "")
            if prima.upper().startswith("ATTIVO"):
                return f
        except Exception:
            pass
    return None


b = blocco_attivo()
if b:
    esci("SQUADRA IN BLOCCO: Andrea ha fermato il lavoro (" + b + "). Non eseguire comandi ne' modificare file. "
         "Puoi solo leggere e riferire. Il blocco lo toglie solo Andrea.")

# ---------------- 2. REGOLE DELLA SQUADRA: file che gli agenti non modificano ----------------
def rel(p):
    p = os.path.abspath(os.path.join(cwd, os.path.expanduser(p)))
    for base in (ROOT, HOME):
        if p == base or p.startswith(base + os.sep):
            return os.path.relpath(p, base).replace(os.sep, "/"), base
    return p.replace(os.sep, "/"), None


PROTETTI = [r"^\.claude/hooks/", r"^\.claude/scripts/", r"^\.claude/agents/", r"^\.claude/commands/", r"^\.claude/modelli/",
            r"^\.claude/settings(\.local)?\.json$", r"^\.claude/zone-protette\.json$", r"^\.claude/backup-ok\.json$",
            r"^\.claude/architettura-preferita\.md$", r"^\.claude/CLAUDE\.md$", r"^CLAUDE\.md$", r"^\.github/",
            r"^BLOCCO-SQUADRA\.md$", r"^\.claude/BLOCCO-SQUADRA\.md$"]
# file di configurazione che si possono CREARE la prima volta (impostazione del progetto) ma poi non si modificano
SOLO_CREAZIONE = [r"^\.claude/produzione\.json$", r"^\.claude/progetto\.json$"]

if SCRIVE_FILE:
    target = tin.get("file_path") or tin.get("notebook_path") or ""
    r, base = rel(target)
    if re.search(r"(^|/)BLOCCO-SQUADRA\.md$", r):
        nuovo = (tin.get("content") or "").strip().upper()
        if not (tool == "Write" and nuovo.startswith("ATTIVO")):
            esci("BLOCCATO: il file BLOCCO-SQUADRA.md lo modifica o lo toglie solo Andrea (gli agenti possono solo crearlo con ATTIVO, su sua richiesta).")
        sys.exit(0)
    if base is not None and any(re.search(p, r) for p in PROTETTI):
        blocca("modifica di un file delle regole della squadra (" + r + "). Le regole, la guardia, la CI e le zone protette le cambia solo Andrea "
               "(reinstallando il pacchetto da solo, oppure con una pull request che approva lui).")
    if base is not None and any(re.search(p, r) for p in SOLO_CREAZIONE):
        if os.path.exists(os.path.abspath(os.path.join(cwd, os.path.expanduser(target)))):
            blocca("modifica di " + r + " dopo la prima impostazione. Se va cambiato, scrivi la proposta nel registro decisioni: lo cambia Andrea.")
    sys.exit(0)

if tool != "Bash":
    sys.exit(0)

c = cmd
# installazione/aggiornamento del pacchetto: solo Andrea
if re.search(r"\binstalla(-nel-progetto)?\.sh\b", c):
    blocca("installazione o aggiornamento della squadra. Lo esegue solo Andrea, da terminale.")
# Sui file delle regole (e sul file di blocco) sono ammesse SOLO letture: leggere, cercare, elencare, confrontare.
NOMI_PROTETTI = r"(BLOCCO-SQUADRA|guardia-produzione|settings(\.local)?\.json|zone-protette|backup-ok\.json|produzione\.json|progetto\.json|architettura-preferita|CLAUDE\.md|\.github\b|\.claude\b)"
SOLO_LETTURA = (r"^(cat|less|more|head|tail|grep|egrep|fgrep|rg|ls|wc|diff|cmp|file|stat|readlink|realpath|tree|sort|uniq|cut|nl|"
                r"sha256sum|md5sum|jq|test|\[|find|python3\s+-m\s+json\.tool|"
                r"git\s+(add|commit|status|diff|log|show|blame|ls-files|grep|cat-file|rev-parse|ls-tree))\b"
                # eseguire (non modificare) gli script della squadra
                r"|^((bash|sh|python3?)\s+)?(\./|~/|\$HOME/|\$CLAUDE_PROJECT_DIR/|\"\$CLAUDE_PROJECT_DIR\"/)?\.claude/scripts/[\w.-]+(\s|$)")
INNOCUE = r"\d?>\s*/dev/null|&>\s*/dev/null|\d>&\d"          # redirezioni che non scrivono file
if re.search(NOMI_PROTETTI, c):
    for seg in re.split(r"\|\||&&|;|\||\n", c):
        seg = seg.strip()
        if not seg or not re.search(NOMI_PROTETTI, seg):
            continue
        senza = re.sub(INNOCUE, " ", seg)
        scrive = (not re.match(SOLO_LETTURA, senza)) or (">" in senza) \
            or (senza.startswith("find") and re.search(r"\s-(delete|exec|execdir|ok|okdir|fprint\w*|fls)\b", senza))
        if scrive:
            blocca("comando che puo' modificare file delle regole della squadra o il file di blocco (" + seg[:80] + "). Su quei file sono ammesse solo letture.")

# Su GitHub gli agenti possono LEGGERE impostazioni e stati, ma non cambiare approvazioni, protezioni, ambienti, segreti o accessi.
if re.search(r"\bgh\s+api\b", c):
    for seg in re.split(r"\|\||&&|;|\||\n", c):
        if not re.search(r"\bgh\s+api\b", seg):
            continue
        sensibile = re.search(r"(pending_deployments|/environments|/protection|/rulesets|/actions/(secrets|variables|permissions)|/collaborators|/hooks|/keys|/deployments)", seg)
        scrittura = re.search(r"(-X|--method)\s*(POST|PUT|PATCH|DELETE)\b|\s(-f|-F|--field|--raw-field|--input)\b", seg, re.IGNORECASE)
        if sensibile and scrittura:
            blocca("modifica di approvazioni, protezioni, ambienti, segreti o accessi su GitHub")
        if re.search(r"(-X|--method)\s*DELETE\b", seg, re.IGNORECASE):
            blocca("cancellazione tramite API GitHub")

# ---------------- 3. COMANDI DISTRUTTIVI ----------------
REGOLE = [
    (r"\bDROP\s+(TABLE|DATABASE|SCHEMA|COLUMN|INDEX)\b", "DROP su tabelle/database/colonne"),
    (r"\bTRUNCATE\b", "TRUNCATE (svuota una tabella)"),
    (r"dropDatabase|\.drop\(\)", "drop di database/collezioni"),
    (r"\b(migrate:fresh|migrate:reset|db:drop|db:reset)\b", "reset del database"),
    # ---- Firebase / Google Cloud: cancellazioni ----
    (r"\bfirebase\s+firestore:delete\b", "cancellazione di documenti o collezioni Firestore (firebase firestore:delete)"),
    (r"\bgcloud\s+firestore\s+databases\s+delete\b", "cancellazione di un database Firestore"),
    (r"\bgcloud\s+firestore\s+(indexes|fields)\b[^\n;|&]*\bdelete\b", "cancellazione di indici Firestore"),
    (r"\brecursiveDelete\b|\.listDocuments\(\)[^\n;|&]*\.delete\(", "cancellazione ricorsiva di dati Firestore"),
    (r"\bgcloud\s+functions\s+delete\b|\bfirebase\s+functions:delete\b", "cancellazione di una Cloud Function"),
    (r"\bgcloud\s+run\s+services\s+delete\b", "cancellazione di un servizio Cloud Run"),
    (r"\bgcloud\s+projects\s+(delete|undelete)\b", "cancellazione di un progetto Google Cloud"),
    (r"\bgcloud\s+iam\s+service-accounts\s+(delete|keys\s+(create|delete))\b", "creazione/cancellazione di chiavi o account di servizio"),
    (r"\bgcloud\s+secrets\s+(delete|versions\s+(destroy|disable|add))\b|\bfirebase\s+functions:secrets:(set|destroy|prune)\b", "modifica o cancellazione di segreti"),
    (r"\bfirebase\s+hosting:disable\b", "disattivazione di Firebase Hosting"),
    (r"\bgcloud\s+storage\s+buckets\s+(delete|update)\b|\bgsutil\s+(rb|retention|lifecycle)\b", "cancellazione o modifica di un bucket (retention, lifecycle)"),
    # ---- Git ----
    (r"\bgit\s+push\b[^\n;|&]*(--force\b|--force-with-lease\b|\s-f\b|\s\+\S|--delete\b|\s:\S)", "git push forzato o cancellazione di rami remoti"),
    (r"\bgit\s+push\b[^\n;|&]*(\s|:)(refs/heads/)?(main|master|staging|produzione|production)(\s|$)", "push diretto su un ramo protetto (main/staging): si passa solo da pull request con i controlli"),
    (r"\bgit\s+reset\s+--hard\b", "git reset --hard"),
    (r"\bgit\s+clean\b[^\n;|&]*-\w*f", "git clean -f"),
    (r"\bgit\s+branch\s+-D\b", "cancellazione forzata di branch"),
    (r"\bgit\s+(checkout|restore)\s+(--\s+)?\.(\s|$)", "scarto di tutte le modifiche locali"),
    (r"\bgit\s+(tag\s+-d|tag\s+--delete)\b", "cancellazione di tag"),
    # ---- 6. decisioni di Andrea su GitHub ----
    (r"\bgh\s+pr\s+merge\b[^\n;|&]*--admin", "merge forzato da amministratore"),
    (r"\bgh\s+pr\s+merge\b[^\n;|&]*--(base|into)[ =]+main\b", "fusione di una pull request in main: in produzione ci arriva solo la promozione da staging con i controlli e l'approvazione di Andrea"),
    (r"\bgh\s+pr\s+review\b[^\n;|&]*(--approve|-a\b)", "approvazione di pull request: le approvazioni su GitHub sono di Andrea"),
    (r"\bgh\s+(secret|variable)\s+(set|delete|remove)\b", "modifica di segreti o variabili di GitHub"),
    (r"\bgh\s+(workflow\s+(disable|enable)|repo\s+(edit|delete|rename|archive)|release\s+delete|run\s+delete|label\s+delete)\b", "modifica della configurazione del repository o dei flussi su GitHub"),
    (r"\bgh\s+auth\b[^\n;|&]*\b(token|refresh|login|switch)\b", "gestione delle credenziali GitHub"),
]
for pattern, spiegazione in REGOLE:
    if re.search(pattern, c, re.IGNORECASE | re.DOTALL):
        blocca(spiegazione + ".")

# ---------------- 4. BACKUP: mai cancellati, spostati o sovrascritti ----------------
if re.search(r"\b(rm|rmdir|unlink|shred|truncate|mv)\b[^\n;|&]*backup|find\b[^\n;|&]*backup[^\n;|&]*-(delete|exec)|>\s*\S*(INDICE-BACKUP|backup)|\bchmod\b[^\n;|&]*\+?w[^\n;|&]*backup|gsutil\s+(rm|mv)|gcloud\s+storage\s+(rm|mv)|\baws\s+s3\s+(rm|mv)", c, re.IGNORECASE):
    blocca("cancellazione, spostamento o modifica di backup. I backup non si cancellano mai.")

# ---------------- 5. PRODUZIONE (richiede .claude/produzione.json) ----------------
cfg, root, d = None, None, cwd
while True:
    f = os.path.join(d, ".claude", "produzione.json")
    if os.path.isfile(f):
        try:
            cfg = json.load(open(f, encoding="utf-8")); root = d
        except Exception:
            blocca("il file .claude/produzione.json non e' leggibile.")
        break
    if os.path.dirname(d) == d:
        break
    d = os.path.dirname(d)

if cfg:
    in_prod = any(cwd.startswith(os.path.abspath(x)) for x in cfg.get("cartelle_produzione", []) if x)
    in_prod = in_prod or any(re.search(m, c, re.IGNORECASE) for m in cfg.get("marcatori", []) if m)
    if in_prod:
        via_script = re.search(r"(ripristina-firestore|backup-firestore)\.sh", c)
        # i rilasci in produzione li fa SOLO la CI (con i controlli e l'approvazione): mai gli agenti
        if re.search(r"\bfirebase\s+(deploy|hosting:channel:deploy)\b|\bgcloud\s+functions\s+deploy\b|\bgcloud\s+run\s+deploy\b", c, re.IGNORECASE):
            blocca("rilascio diretto in produzione (senza un progetto di test esplicito). In produzione si pubblica solo con la procedura di rilascio (CI) dopo la promozione da staging. "
                   "Per provare usa il progetto di test: --project avanza-test.")
        # ripristino manuale: si usa solo ripristina-firestore.sh (prova su copia), il ripristino vero e' una decisione di Andrea
        if not via_script and re.search(r"\bgcloud\s+firestore\s+import\b|\bfirebase\s+firestore:import\b", c, re.IGNORECASE):
            blocca("importazione/ripristino manuale di dati Firestore in produzione. Si usa solo .claude/scripts/ripristina-firestore.sh (prova su copia); il ripristino reale e' una decisione di Andrea.")
        if re.search(r"\bfirestore:delete\b|\bDELETE\s+FROM\b|\.deleteMany|\.deleteOne|\brecursiveDelete\b|\bdatabases\s+delete\b", c, re.IGNORECASE | re.DOTALL):
            blocca("cancellazione di dati in produzione. La squadra non cancella mai dati reali: si archivia o si disattiva.")
        scrittura = re.search(
            r"\bgcloud\s+firestore\s+(import|indexes\s+(composite|fields)\s+(create|update)|databases\s+(create|update))\b"
            r"|\bfirebase\s+firestore:"
            r"|\bgit\s+push\b"
            r"|\bnode\s+\S*scripts/(registra-ore|e2e-webhook)\.mjs\b",
            c, re.IGNORECASE | re.DOTALL)
        if scrittura and not via_script:
            minuti = int(cfg.get("validita_backup_minuti", 30))
            ok = False
            try:
                m = json.load(open(os.path.join(root, ".claude", "backup-ok.json"), encoding="utf-8"))
                ok = (time.time() - float(m["epoch"])) <= minuti * 60 and os.path.isfile(m["file"]) and os.path.getsize(m["file"]) > 0
            except Exception:
                ok = False
            if not ok:
                blocca("operazione che modifica la produzione senza un backup verificato negli ultimi %d minuti. "
                       "Esegui prima .claude/scripts/backup-firestore.sh (oppure /backup) e poi riprova." % minuti)
sys.exit(0)
