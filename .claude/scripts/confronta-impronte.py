#!/usr/bin/env python3
"""Confronta due impronte del database Firestore (prima/dopo un rilascio). Solo lettura.
Formato: righe "collezione<TAB>documenti<TAB>hash" (impronta-firestore.mjs) oppure il suo output --json.

Uso: confronta-impronte.py <impronta-prima> <impronta-dopo> [--stesse-righe]
 - ERRORE se una collezione che esisteva prima non c'e' piu';
 - ERRORE se una collezione ha MENO documenti di prima (dati spariti);
 - con --stesse-righe (prova su una copia senza utenti): ERRORE anche se il numero di righe cambia;
 - le collezioni nuove sono ammesse (le modifiche sono solo aggiunte) e vengono elencate.
Il contenuto (hash) puo' cambiare legittimamente con una colonna nuova o con gli utenti al lavoro: non e' un errore, viene solo riportato.
Esce con 1 se c'e' anche un solo errore.
"""
import sys


def leggi(p):
    t = {}
    testo = open(p, encoding="utf-8").read()
    if testo.lstrip().startswith("{"):
        import json
        for c in json.loads(testo).get("collezioni", []):
            t[c["collezione"]] = (int(c["documenti"]), c.get("hash", ""))
        return t
    for r in testo.splitlines():
        parti = r.rstrip("\n").split("\t")
        if len(parti) >= 2 and parti[0]:
            t[parti[0]] = (int(parti[1]), parti[2] if len(parti) > 2 else "")
    return t


def main():
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    if len(a) != 2:
        print(__doc__); return 2
    stesse = "--stesse-righe" in sys.argv
    prima, dopo = leggi(a[0]), leggi(a[1])
    if not prima:
        print("ERRORE: impronta 'prima' vuota"); return 1
    errori, note = [], []
    for t, (n, h) in sorted(prima.items()):
        if t not in dopo:
            errori.append(f"collezione SPARITA: {t} (aveva {n} documenti)"); continue
        n2, h2 = dopo[t]
        if n2 < n:
            errori.append(f"documenti DIMINUITI in {t}: {n} -> {n2}")
        elif stesse and n2 != n:
            errori.append(f"documenti cambiati in {t} sulla copia: {n} -> {n2}")
        elif n2 > n:
            note.append(f"documenti aggiunti in {t}: {n} -> {n2}")
        elif h2 != h:
            note.append(f"contenuto cambiato in {t} (stessi documenti: campo nuovo o aggiornamenti degli utenti)")
    for t in sorted(set(dopo) - set(prima)):
        note.append(f"collezione nuova: {t}")
    for n in note:
        print("NOTA:", n)
    for e in errori:
        print("ERRORE:", e)
    if errori:
        print("CONFRONTO: ANOMALIA"); return 1
    print(f"CONFRONTO: OK ({len(prima)} collezioni controllate, nessun dato sparito)"); return 0


if __name__ == "__main__":
    sys.exit(main())
