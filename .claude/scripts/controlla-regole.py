#!/usr/bin/env python3
"""Controllo AUTOMATICO delle regole di sicurezza e degli indici di Firestore (non dipende da nessun agente).
Verifica che le modifiche a firestore.rules e firestore.indexes.json siano sicure.

Uso: controlla-regole.py <ramo-base> [--regole firestore.rules] [--indici firestore.indexes.json]
  <ramo-base>  ramo/commit di confronto (es. origin/staging): si guardano le differenze rispetto a HEAD.

Regole (firestore.rules) - ERRORE se una regola `allow` NUOVA o MODIFICATA:
  - e' `if true` (apre i dati a chiunque, anche senza accesso);
  - non contiene alcun controllo di accesso (request.auth, signedIn(), isAdmin(), isProjectOwner(...), isLinkedClient(...), false).
  Le regole che restano invariate non vengono riesaminate. AVVISO se sparisce un controllo gia' presente.
Indici (firestore.indexes.json) - ERRORE se:
  - il file non e' un JSON valido;
  - un indice che esisteva nel ramo base non c'e' piu' (le query dell'app potrebbero smettere di funzionare);
  Gli indici nuovi sono ammessi.
Esito: 0 = ok (anche con avvisi); 1 = almeno un ERRORE (la modifica non entra da sola)."""
import json, re, subprocess, sys

args = sys.argv[1:]
base = args[0] if args and not args[0].startswith("--") else "origin/main"
def opz(nome, default):
    return args[args.index(nome) + 1] if nome in args else default
F_REGOLE = opz("--regole", "firestore.rules")
F_INDICI = opz("--indici", "firestore.indexes.json")

CONTROLLI_ACCESSO = re.compile(r"request\.auth|signedIn\s*\(|isAdmin\s*\(|isProjectOwner\s*\(|isLinkedClient\s*\(|\bfalse\b")


def git_show(rif, path):
    r = subprocess.run(["git", "show", f"{rif}:{path}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def lavoro(path):
    try:
        return open(path, encoding="utf-8").read()
    except FileNotFoundError:
        return None


def istruzioni_allow(testo):
    """Elenco normalizzato delle istruzioni `allow ...: if ...;`."""
    pulito = re.sub(r"//[^\n]*", "", testo or "")
    out = []
    for m in re.finditer(r"allow\s+([^:;]+):\s*(?:if\s+)?([^;]*);", pulito):
        out.append((re.sub(r"\s+", " ", m.group(1)).strip(), re.sub(r"\s+", " ", m.group(2)).strip()))
    return out


errori, avvisi = [], []

# ---- regole ----
vecchie, nuove = git_show(base, F_REGOLE), lavoro(F_REGOLE)
if nuove is None:
    if vecchie is not None:
        errori.append(f"{F_REGOLE}: file cancellato (i dati resterebbero senza regole)")
elif nuove != vecchie:
    prima = set(istruzioni_allow(vecchie))
    for op, cond in istruzioni_allow(nuove):
        if (op, cond) in prima:
            continue
        sigla = f"allow {op}: {cond[:80]}"
        if cond.lower() in ("true", "if true") or re.fullmatch(r"true", cond, re.I):
            errori.append(f"regola aperta a chiunque (if true): {sigla}")
        elif not CONTROLLI_ACCESSO.search(cond):
            errori.append(f"regola senza controllo di accesso: {sigla}")
    # un controllo che sparisce e' solo un avviso (puo' essere un riordino)
    n_prima = len(re.findall(r"request\.auth", vecchie or ""))
    n_dopo = len(re.findall(r"request\.auth", nuove))
    if n_dopo < n_prima:
        avvisi.append(f"{F_REGOLE}: i controlli request.auth passano da {n_prima} a {n_dopo} (verifica che non sia stata aperta una regola)")
    if "rules_version" not in nuove:
        errori.append(f"{F_REGOLE}: manca rules_version")
else:
    print(f"{F_REGOLE}: nessuna modifica")

# ---- indici ----
def chiavi_indici(testo):
    d = json.loads(testo)
    out = set()
    for i in d.get("indexes", []):
        campi = tuple((c.get("fieldPath"), c.get("order") or c.get("arrayConfig")) for c in i.get("fields", []))
        out.add((i.get("collectionGroup"), i.get("queryScope", "COLLECTION"), campi))
    return out

v_ind, n_ind = git_show(base, F_INDICI), lavoro(F_INDICI)
if n_ind is None:
    if v_ind is not None:
        errori.append(f"{F_INDICI}: file cancellato")
elif n_ind != v_ind:
    try:
        nuovi = chiavi_indici(n_ind)
    except Exception as e:
        errori.append(f"{F_INDICI}: JSON non valido ({e})")
        nuovi = None
    if nuovi is not None and v_ind:
        try:
            for k in sorted(chiavi_indici(v_ind) - nuovi, key=str):
                errori.append(f"indice RIMOSSO: {k[0]} {[c[0] for c in k[2]]}: le query che lo usano smetterebbero di funzionare")
        except Exception:
            avvisi.append(f"{F_INDICI}: il file del ramo base non e' leggibile, confronto saltato")
else:
    print(f"{F_INDICI}: nessuna modifica")

for a in avvisi:
    print("AVVISO:", a)
for e in errori:
    print("ERRORE:", e)
if errori:
    print("REGOLE: NO (serve la revisione di Andrea)")
    sys.exit(1)
print("REGOLE: OK")
sys.exit(0)
