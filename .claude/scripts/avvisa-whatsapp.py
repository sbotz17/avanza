#!/usr/bin/env python3
"""Invia un avviso ad Andrea su WhatsApp. OGNI messaggio inizia con il nome del progetto: "[Avanza] ...".

Due modalita':
 1) MOTORE DI ANDREA (il server WhatsApp di piattaforma, lo stesso usato da Volty): se AVVISI_URL e' impostata,
    fa POST <AVVISI_URL>/invia con intestazione x-api-key: $AVVISI_TOKEN e corpo {"numero": $AVVISI_NUMERO, "testo": "[Progetto] Tipo: testo"}.
    AVVISI_URL = indirizzo base del server (es. https://wa.tuodominio.it), AVVISI_NUMERO = il numero di Andrea (solo cifre, con prefisso 39).
    Il server deve essere raggiungibile in HTTPS: la chiave viaggia nell'intestazione. Solo se proprio non e' possibile,
    AVVISI_PERMETTI_HTTP=si accetta http:// (sconsigliato: chiunque in mezzo potrebbe leggere la chiave).
 2) Diretta con WhatsApp Business Cloud API di Meta (modello approvato), se AVVISI_URL non c'e'.

Nome progetto: variabile AVVISI_PROGETTO, oppure `.claude/progetto.json` ({"nome": "Avanza"}). Senza nome progetto NON si invia.

Uso:  avvisa-whatsapp.py <tipo> "<testo breve>" [--dry-run]
Tipi (elenco chiuso): da_validare | decisione_in_sospeso | rilasciato | anomalia | segnalazione | blocco | altro
Variabili (SEGRETI della CI / delle Edge Function, MAI nei file e MAI agli agenti):
  WHATSAPP_TOKEN, WHATSAPP_PHONE_ID (id del numero mittente), WHATSAPP_DESTINATARIO (il tuo numero, formato internazionale senza +),
  WHATSAPP_MODELLO (nome del modello approvato, default 'avviso_squadra'), WHATSAPP_LINGUA (default 'it')
SE NESSUN MOTORE E' CONFIGURATO (ne' AVVISI_URL ne' WHATSAPP_TOKEN) l'avviso NON parte: lo script lo dice chiaramente
e termina senza errore (il flusso che lo chiama non si ferma). Nel resoconto in chat si scrive che l'avviso non e' partito.
Il modello da approvare su Meta ha UNA variabile nel corpo, es.:  "Squadra {{1}}"
Il testo e' ripulito (niente a capo, max 280 caratteri) e non deve contenere dati personali: chi chiama passa solo testi composti da modelli fissi.
"""
import json, os, re, sys, urllib.request, urllib.error

TIPI = {"da_validare": "Sviluppo da validare", "decisione_in_sospeso": "Decisione in sospeso", "rilasciato": "Rilascio eseguito",
        "anomalia": "ANOMALIA", "segnalazione": "Nuova segnalazione", "blocco": "Squadra in blocco", "altro": "Avviso"}


def pulisci(t):
    t = re.sub(r"\s+", " ", t).strip()
    t = re.sub(r"https?://\S+", "[link]", t) if os.environ.get("AVVISO_SENZA_LINK") else t
    return t[:280]


def progetto():
    n = os.environ.get("AVVISI_PROGETTO", "").strip()
    if not n:
        for p in (".claude/progetto.json", os.path.join(os.environ.get("CLAUDE_PROJECT_DIR", "."), ".claude/progetto.json")):
            try:
                n = json.load(open(p, encoding="utf-8")).get("nome", "").strip()
                if n: break
            except Exception:
                pass
    n = re.sub(r"[^\w .\-]", "", n)[:40].strip()
    return n


def invia_motore(url, tok, numero, testo):
    corpo = {"numero": numero, "testo": testo}
    req = urllib.request.Request(url.rstrip("/") + "/invia", data=json.dumps(corpo, ensure_ascii=False).encode(), method="POST",
                                 headers={"x-api-key": tok, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.status


def main():
    a = [x for x in sys.argv[1:] if x != "--dry-run"]
    dry = "--dry-run" in sys.argv
    if len(a) != 2 or a[0] not in TIPI:
        print(__doc__); return 2
    prog = progetto()
    if not prog:
        print("ERRORE: nome progetto mancante (AVVISI_PROGETTO o .claude/progetto.json): l'avviso non e' partito"); return 1
    testo = "[" + prog + "] " + TIPI[a[0]] + ": " + pulisci(a[1])
    url = os.environ.get("AVVISI_URL", "")
    if not dry and not url and not os.environ.get("WHATSAPP_TOKEN"):
        print("AVVISO NON PARTITO: motore WhatsApp non configurato (AVVISI_URL / WHATSAPP_TOKEN assenti). Testo: " + testo)
        return 0
    if url and not dry:
        tok, numero = os.environ.get("AVVISI_TOKEN", ""), re.sub(r"\D", "", os.environ.get("AVVISI_NUMERO", ""))
        http_ok = os.environ.get("AVVISI_PERMETTI_HTTP", "").lower() == "si" and url.startswith("http://")
        if not (url.startswith("https://") or http_ok) or not tok or not re.fullmatch(r"\d{8,15}", numero):
            print("ERRORE: servono AVVISI_URL (https), AVVISI_TOKEN e AVVISI_NUMERO (solo cifre): l'avviso non e' partito"); return 1
        try:
            print("Avviso inviato al motore, HTTP", invia_motore(url, tok, numero, testo)); return 0
        except urllib.error.HTTPError as e:
            print("ERRORE HTTP", e.code, "(l'avviso non e' partito)"); return 1
        except Exception as e:
            print("ERRORE di rete:", e); return 1
    corpo = {"messaging_product": "whatsapp", "to": os.environ.get("WHATSAPP_DESTINATARIO", "000"), "type": "template",
             "template": {"name": os.environ.get("WHATSAPP_MODELLO", "avviso_squadra"),
                          "language": {"code": os.environ.get("WHATSAPP_LINGUA", "it")},
                          "components": [{"type": "body", "parameters": [{"type": "text", "text": testo}]}]}}
    if dry:
        corpo["to"] = "<numero-nascosto>"; print("DRY-RUN, avrei inviato:", json.dumps(corpo, ensure_ascii=False)); return 0
    tok, pid, to = (os.environ.get(k) for k in ("WHATSAPP_TOKEN", "WHATSAPP_PHONE_ID", "WHATSAPP_DESTINATARIO"))
    if not (tok and pid and to and re.fullmatch(r"\d{8,15}", to)):
        print("ERRORE: WHATSAPP_TOKEN, WHATSAPP_PHONE_ID, WHATSAPP_DESTINATARIO (solo cifre) obbligatori"); return 1
    req = urllib.request.Request(f"https://graph.facebook.com/v21.0/{pid}/messages", data=json.dumps(corpo).encode(), method="POST",
                                 headers={"Authorization": "Bearer " + tok, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            print("Avviso inviato, HTTP", r.status); return 0
    except urllib.error.HTTPError as e:
        print("ERRORE HTTP", e.code, "(l'avviso non e' partito)"); return 1
    except Exception as e:
        print("ERRORE di rete:", e); return 1


if __name__ == "__main__":
    sys.exit(main())
