#!/usr/bin/env python3
"""Decide in modo AUTOMATICO se cio' che sta per andare in produzione e' una CORREZIONE (rilascio autonomo)
oppure un NUOVO SVILUPPO (serve l'approvazione di Andrea). Nel dubbio: SVILUPPO.

Uso: classifica-modifica.py <rif-base> <richieste.json> [config-zone-protette.json] [--rilasci-segnalazioni-oggi N]
  <rif-base>       cio' che e' gia' in produzione (il ramo main)
  <richieste.json> elenco delle pull request che compongono le modifiche tra <rif-base> e HEAD, preparato dalla CI:
                   {"commit_senza_pr": 0, "pr": [{"numero": 12, "ramo": "fix/R-7", "etichette": ["tipo:correzione"], "titolo": "...", "corpo": "..."}]}
E' CORREZIONE solo se TUTTE le condizioni sono vere:
  1. ogni modifica viene da una pull request (nessun commit diretto);
  2. ogni pull request ha l'etichetta tipo:correzione, un ramo con prefisso ammesso (fix/, hotfix/, claude/segnalazione-)
     e un riferimento al ritorno (R-numero) nel titolo o nella descrizione;
  3. l'insieme delle modifiche non tocca le zone protette (regole Firestore, permessi, configurazioni, dipendenze, CI, regole della squadra...)
     e resta nei limiti di file e righe (piu' stretti se c'e' una segnalazione esterna);
  4. per le correzioni nate da segnalazioni esterne: non si supera il tetto giornaliero di rilasci.
Stampa i motivi e, per ultima, la riga TIPO=correzione oppure TIPO=sviluppo (scritta anche in $GITHUB_OUTPUT se presente).
"""
import fnmatch, json, os, re, subprocess, sys


def scrivi(tipo, motivi):
    for m in motivi:
        print("MOTIVO:", m)
    print("TIPO=" + tipo)
    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as f:
            f.write("tipo=%s\n" % tipo)
            f.write("motivo=%s\n" % ("; ".join(motivi)[:300].replace("\n", " ") if motivi else "tutte le condizioni rispettate"))
    return 0


def main():
    a = sys.argv[1:]
    oggi = 0
    if "--rilasci-segnalazioni-oggi" in a:
        i = a.index("--rilasci-segnalazioni-oggi"); oggi = int(a[i + 1]); del a[i:i + 2]
    if len(a) < 2:
        print(__doc__); return 2
    base, rich = a[0], a[1]
    cfgp = a[2] if len(a) > 2 else ".claude/zone-protette.json"
    cfg = json.load(open(cfgp, encoding="utf-8")) if os.path.exists(cfgp) else {}
    prefissi = cfg.get("prefissi_correzione", ["fix/", "hotfix/", "claude/segnalazione-"])
    esterni = cfg.get("rami_soggetti", ["claude/segnalazione-"])
    protette = cfg.get("protette", [])
    motivi = []
    try:
        r = json.load(open(rich, encoding="utf-8"))
    except Exception:
        return scrivi("sviluppo", ["elenco delle pull request non leggibile"])
    prs = r.get("pr") or []
    if r.get("commit_senza_pr", 1):
        motivi.append("ci sono modifiche entrate senza pull request")
    if not prs:
        motivi.append("nessuna pull request trovata")
    ha_esterne = False
    for p in prs:
        n, ramo = p.get("numero"), p.get("ramo") or ""
        et = p.get("etichette") or []
        testo = (p.get("titolo") or "") + " " + (p.get("corpo") or "")
        if "tipo:correzione" not in et:
            motivi.append(f"PR {n}: manca l'etichetta tipo:correzione")
        if not any(ramo.startswith(x) for x in prefissi):
            motivi.append(f"PR {n}: ramo non da correzione")
        if not re.search(r"\bR-\d{1,6}\b", testo):
            motivi.append(f"PR {n}: manca il riferimento al ritorno (R-numero)")
        if any(ramo.startswith(x) for x in esterni):
            ha_esterne = True
    # modifiche complessive rispetto alla produzione
    try:
        out = subprocess.run(["git", "diff", "--numstat", "--no-renames", base + "..HEAD"], capture_output=True, text=True, check=True).stdout
    except Exception:
        return scrivi("sviluppo", motivi + ["impossibile calcolare le modifiche rispetto alla produzione"])
    file_mod, righe = [], 0
    for riga in out.splitlines():
        x, y, path = riga.split("\t", 2)
        file_mod.append(path)
        righe += (int(x) if x.isdigit() else 9999) + (int(y) if y.isdigit() else 9999)
    prot = [p for p in file_mod if any(fnmatch.fnmatch(p, pat) or fnmatch.fnmatch(os.path.basename(p), pat) for pat in protette)]
    if prot:
        motivi.append("tocca zone protette: " + ", ".join(prot[:5]) + (" ..." if len(prot) > 5 else ""))
    mf = int(cfg.get("max_file_modificati" if ha_esterne else "max_file_correzione", 8 if ha_esterne else 15))
    mr = int(cfg.get("max_righe_modificate" if ha_esterne else "max_righe_correzione", 300 if ha_esterne else 400))
    if len(file_mod) > mf:
        motivi.append(f"troppi file: {len(file_mod)} (massimo {mf})")
    if righe > mr:
        motivi.append(f"troppe righe: {righe} (massimo {mr})")
    if not file_mod:
        motivi.append("nessuna modifica rispetto alla produzione")
    tetto = int(cfg.get("max_rilasci_segnalazioni_giorno", 3))
    if ha_esterne and oggi >= tetto:
        motivi.append(f"raggiunto il tetto giornaliero di rilasci da segnalazioni esterne ({tetto})")
    if motivi:
        return scrivi("sviluppo", motivi)
    print(f"Correzione: {len(prs)} pull request, {len(file_mod)} file, {righe} righe, nessuna zona protetta")
    return scrivi("correzione", [])


if __name__ == "__main__":
    sys.exit(main())
