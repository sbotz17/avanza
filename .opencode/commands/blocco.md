---
description: "Andrea ferma subito la squadra (solo Andrea la riavvia)"
agent: coordinatore
---

Andrea vuole FERMARE la squadra. Motivo: $ARGUMENTS

1. Crea nella cartella del progetto il file `BLOCCO-SQUADRA.md` con prima riga `ATTIVO` (poi data e motivo). È l'unica scrittura che la guardia permette su quel file.
2. Da quel momento la guardia blocca ogni strumento in questa sessione e nelle altre sessioni sullo stesso computer: nessun agente può proseguire né modificare o togliere il file. (Per fermare tutti i progetti del computer, lo stesso file può stare in `.claude/`.)
3. Spiega ad Andrea come fermare anche il resto, perché il file resta sul computer:
   - CI (promozioni, rilasci, invio esiti): su GitHub > repository di sviluppo e di produzione > Settings > Secrets and variables > Actions > Variables > `BLOCCO_SQUADRA` = `ATTIVO` (si fa anche dal browser del telefono);
   - routine delle segnalazioni e sessioni cloud: mettere in pausa la routine su claude.ai e interrompere le sessioni.
4. Come si riparte (solo Andrea): cancellare a mano il file `BLOCCO-SQUADRA.md` (o cambiare la prima riga in `DISATTIVO`) e svuotare la variabile `BLOCCO_SQUADRA`.
5. Il backup notturno continua anche durante il blocco: protegge, non modifica nulla.
