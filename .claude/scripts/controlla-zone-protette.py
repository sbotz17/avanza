#!/usr/bin/env python3
"""Controllo AUTOMATICO: una correzione nata da una SEGNALAZIONE ESTERNA non puo' toccare le zone protette
(sicurezza, accessi, configurazioni, dipendenze, regole della squadra) ne' essere troppo grande: in quei casi
non si rilascia da sola e aspetta la revisione di Andrea.
Uso: controlla-zone-protette.py <ramo-base> <nome-ramo-della-modifica> [file-config.json] [--sempre]
  --sempre: applica il controllo qualunque sia il ramo (usato dalla classificazione correzione/sviluppo)
Esito: 0 = ok o non soggetto; 1 = tocca zone protette o supera i limiti."""
import fnmatch, json, subprocess, sys, os

SEMPRE = "--sempre" in sys.argv
args = [a for a in sys.argv[1:] if a != "--sempre"]
base = args[0] if len(args) > 0 else "origin/main"
ramo = args[1] if len(args) > 1 else ""
cfgp = args[2] if len(args) > 2 else ".claude/zone-protette.json"
cfg = json.load(open(cfgp, encoding="utf-8")) if os.path.exists(cfgp) else {}
soggetti = cfg.get("rami_soggetti", ["claude/segnalazione-"])
if not SEMPRE and not any(ramo.startswith(p) for p in soggetti):
    print("ZONE PROTETTE: modifica non soggetta (non nata da una segnalazione esterna)"); sys.exit(0)

protette = cfg.get("protette", [])
max_file = int(cfg.get("max_file_modificati", 8)); max_righe = int(cfg.get("max_righe_modificate", 300))
out = subprocess.run(["git", "diff", "--numstat", "--no-renames", base + "...HEAD"], capture_output=True, text=True, check=True).stdout
file_mod, righe = [], 0
for r in out.splitlines():
    a, d, p = r.split("\t", 2)
    file_mod.append(p)
    righe += (int(a) if a.isdigit() else 9999) + (int(d) if d.isdigit() else 9999)

def protetto(p):
    return any(fnmatch.fnmatch(p, pat) or fnmatch.fnmatch(os.path.basename(p), pat) for pat in protette)

problemi = [f"file in zona protetta: {p}" for p in file_mod if protetto(p)]
if len(file_mod) > max_file: problemi.append(f"troppi file modificati: {len(file_mod)} (massimo {max_file})")
if righe > max_righe: problemi.append(f"troppe righe modificate: {righe} (massimo {max_righe})")
if not file_mod: problemi.append("nessuna modifica: niente da rilasciare")
for p in problemi: print("BLOCCO:", p)
if problemi:
    print("ZONE PROTETTE: serve la revisione di Andrea, nessun rilascio automatico"); sys.exit(1)
print("ZONE PROTETTE: ok (%d file, %d righe, nessuna zona protetta)" % (len(file_mod), righe)); sys.exit(0)
