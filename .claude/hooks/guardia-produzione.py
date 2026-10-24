#!/usr/bin/env python3
"""Guardia di sicurezza della squadra (hook PreToolUse di Claude Code): exit 2 = azione bloccata, il messaggio arriva a Claude.

Protegge (aggiornato su decisione di Andrea, 24/10/2026: l'unico limite invalicabile sono i DATI):
 1. la leva di Andrea (BLOCCO-SQUADRA.md);
 3. i dati (cancellazioni e reset del database) e la storia Git (comandi distruttivi);
 4. i backup (mai cancellati);
 5. la produzione (niente scritture senza backup recente, niente cancellazioni, niente rilascio diretto).
Le regole della squadra, la CI, le zone protette e le configurazioni di GitHub e Google NON sono piu' bloccate dalla guardia.
E' una rete di sicurezza contro errori evidenti, non l'unica difesa.
"""
import json, os, re, sys, time


def esci(msg):
    sys.stderr.write(msg + "\n")
    sys.exit(2)


def blocca(msg):
    esci("BLOCCATO dalla guardia di sicurezza: " + msg + "\n"
         "Il limite riguarda i dati: cancellare o sovrascrivere dati reali o backup si fa solo insieme ad Andrea. "
         "Non aggirarlo con comandi equivalenti: scrivi la decisione in sospeso in docs/progetto/registro-decisioni.md "
         "(cosa volevi fare, perche', elenco dei record, backup, prova su copia), avvisa Andrea e prosegui con il resto del lavoro. "
         "Vedi Autonomia e limiti in CLAUDE.md.")


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

# ---------------- 2. LEVA DI ANDREA: il file di blocco lo gestisce solo lui ----------------
# (le regole della squadra, la CI, le zone protette e le configurazioni non sono piu' protette: decisione di Andrea del 24/10/2026)
if SCRIVE_FILE:
    target = tin.get("file_path") or tin.get("notebook_path") or ""
    if re.search(r"(^|/)BLOCCO-SQUADRA\.md$", target):
        nuovo = (tin.get("content") or "").strip().upper()
        if not (tool == "Write" and nuovo.startswith("ATTIVO")):
            esci("BLOCCATO: il file BLOCCO-SQUADRA.md lo modifica o lo toglie solo Andrea (gli agenti possono solo crearlo con ATTIVO, su sua richiesta).")
    sys.exit(0)

if tool != "Bash":
    sys.exit(0)

c = cmd
# Sul file di blocco sono ammesse SOLO letture.
NOMI_PROTETTI = r"BLOCCO-SQUADRA"
SOLO_LETTURA = r"^(cat|less|more|head|tail|grep|egrep|fgrep|rg|ls|wc|diff|cmp|file|stat|readlink|realpath|test|\[|find)\b"
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
            esci("BLOCCATO: comando che puo' modificare il file di blocco (" + seg[:80] + "). Il file BLOCCO-SQUADRA.md lo gestisce solo Andrea.")

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
    (r"\bfirebase\s+hosting:disable\b", "disattivazione di Firebase Hosting"),
        (r"\bgcloud\s+storage\s+buckets\s+delete\b|\bgsutil\s+rb\b", "cancellazione di un bucket (possibili backup)"),
    # ---- Git ----
    (r"\bgit\s+push\b[^\n;|&]*(--force\b|--force-with-lease\b|\s-f\b|\s\+\S|--delete\b|\s:\S)", "git push forzato o cancellazione di rami remoti"),
    (r"\bgit\s+push\b[^\n;|&]*(\s|:)(refs/heads/)?(main|master|staging|produzione|production)(\s|$)", "push diretto su un ramo protetto (main/staging): si passa solo da pull request con i controlli"),
    (r"\bgit\s+reset\s+--hard\b", "git reset --hard"),
    (r"\bgit\s+clean\b[^\n;|&]*-\w*f", "git clean -f"),
    (r"\bgit\s+branch\s+-D\b", "cancellazione forzata di branch"),
    (r"\bgit\s+(checkout|restore)\s+(--\s+)?\.(\s|$)", "scarto di tutte le modifiche locali"),
    (r"\bgit\s+(tag\s+-d|tag\s+--delete)\b", "cancellazione di tag"),
    (r"\bgh\s+pr\s+merge\b[^\n;|&]*--(base|into)[ =]+main\b", "fusione di una pull request in main: in produzione ci arriva solo la promozione da staging con i controlli e l'approvazione di Andrea"),
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
