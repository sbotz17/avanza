#!/usr/bin/env bash
# Prova del passo "Prerequisiti" (controlla-prerequisiti-rilascio.sh) con vari scenari. Nessun segreto reale: chiavi finte.
S=/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/rel-sim/.claude/scripts/controlla-prerequisiti-rilascio.sh
run() { echo "### $1"; shift; env -i PATH="$PATH" "$@" bash "$S"; echo "rc=$?"; echo; }
run "nessun segreto" A=1
run "chiave non JSON" FIREBASE_SERVICE_ACCOUNT=abc
run "chiave del progetto di TEST" FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"avanza-test-c33ef"}'
run "chiave di produzione, controlli completi SENZA bucket" COMPLETI=true FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"avanza-b62d7"}'
run "chiave di produzione, controlli completi CON bucket" COMPLETI=true BUCKET=bucket-finto FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"avanza-b62d7"}'
run "chiave di produzione, controlli completi spenti (stato attuale probabile)" FIREBASE_SERVICE_ACCOUNT='{"type":"service_account","project_id":"avanza-b62d7"}'
