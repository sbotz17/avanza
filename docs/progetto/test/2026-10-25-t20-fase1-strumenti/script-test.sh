#!/usr/bin/env bash
# Prova delle azioni collegamento sullo EMULATORE (mai produzione). Eseguito da firebase emulators:exec.
set -u
cd /home/user/avanza/.claude/worktrees/agent-a66f1f7a7de2b0cde
: "${FIRESTORE_EMULATOR_HOST:?}"; : "${FIREBASE_AUTH_EMULATOR_HOST:?}"
export GITHUB_REPOSITORY=sbotz17/avanza
run() { echo; echo "### $*"; env "$@" node scripts/registra-ore.mjs; echo "rc=$?"; }
curl -s -X POST "http://$FIREBASE_AUTH_EMULATOR_HOST/identitytoolkit.googleapis.com/v1/projects/avanza-b62d7/accounts" -H "content-type: application/json" -H "Authorization: Bearer owner" -d "{\"email\":\"andrea@example.com\",\"password\":\"password123\"}" >/dev/null
curl -s -X POST "http://$FIREBASE_AUTH_EMULATOR_HOST/identitytoolkit.googleapis.com/v1/projects/avanza-b62d7/accounts" -H "content-type: application/json" -H "Authorization: Bearer owner" -d "{\"email\":\"altro@example.com\",\"password\":\"password123\"}" >/dev/null
run ACTION=collegamento-stato
run ACTION=collegamento NOTE=attiva EMAIL=andrea@example.com GITHUB_URL=https://github.com/sbotz17/avanza
run ACTION=admin EMAIL=andrea@example.com
run ACTION=collegamento NOTE=attiva EMAIL=altro@example.com GITHUB_URL=https://github.com/sbotz17/avanza
run ACTION=collegamento NOTE=attiva EMAIL=nonesiste@example.com GITHUB_URL=https://github.com/sbotz17/avanza
run ACTION=collegamento NOTE=attiva EMAIL=andrea@example.com GITHUB_URL=https://evil.com/sbotz17/avanza
run ACTION=collegamento NOTE=attiva EMAIL=andrea@example.com GITHUB_URL=https://github.com/sbotz17.evil/avanza
run ACTION=collegamento NOTE=attiva EMAIL=andrea@example.com
run ACTION=collegamento-stato
run ACTION=collegamento NOTE=attiva EMAIL=andrea@example.com GITHUB_URL=https://github.com/sbotz17/avanza
run ACTION=collegamento-stato
run ACTION=collegamento NOTE=ATTIVA EMAIL=andrea@example.com GITHUB_URL=https://github.com/SbOtZ17
run ACTION=collegamento-stato
run ACTION=collegamento NOTE=ciao
run ACTION=collegamento
run ACTION=collegamento NOTE=riammetti
run ACTION=collegamento NOTE=riammetti GITHUB_URL=https://github.com/sbotz17/mai-visto
run ACTION=collegamento NOTE=spegni
run ACTION=collegamento-stato
run ACTION=crea-progetto EMAIL=andrea@example.com PROJECT_NAME=Prova GITHUB_URL=https://github.com/sbotz17/prova-x PROJECT_DESCRIPTION=desc
run ACTION=crea-progetto EMAIL=andrea@example.com PROJECT_NAME=Prova GITHUB_URL=https://GitHub.com/sbotz17/Prova-X/
run ACTION=stato
run ACTION=collegamento-stato
