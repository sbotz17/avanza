"""Mutazioni sulle regole Firestore, sull'EMULATORE: la prova delle regole (rules_audit.py) deve diventare ROSSA per ogni mutazione."""
import json, os, subprocess, urllib.request

RULES = open('/home/user/avanza/.claude/worktrees/agent-ad50f58119a5b3b8a/firestore.rules').read()
MUT = {
    'M1 chat: lettura aperta a ogni utente': ("allow read: if isAdmin() && isProjectOwner(projectId);", "allow read: if signedIn();"),
    'M2 chat: limite di 2000 caratteri tolto': ("            request.resource.data.text.size() <= 2000 &&\n", ""),
    'M3 chat: update/delete consentiti all\'admin': ("allow update, delete: if false;\n        }\n      }\n\n      // Stime", "allow update, delete: if isAdmin();\n        }\n      }\n\n      // Stime"),
    'M4 chat: authorUid non controllato': ("            request.resource.data.authorUid == request.auth.uid &&\n", ""),
    'M5 chat: kind libero (risposte scrivibili dal client)': ("            request.resource.data.kind == 'domanda' &&\n", ""),
    'M6 taskCosts leggibili dal cliente collegato': ("match /taskCosts/{taskId} {\n        allow read, write: if isProjectOwner(projectId);", "match /taskCosts/{taskId} {\n        allow read, write: if isProjectOwner(projectId) || isLinkedClient(projectId);"),
    'M7 users: auto-promozione ad admin consentita': ("request.auth.uid == uid && request.resource.data.role == 'client';", "request.auth.uid == uid;"),
    'M8 collezione githubRepos aperta in lettura (regola aggiunta)': ("    match /teamMembers/{memberId} {", "    match /githubRepos/{id} { allow read: if signedIn(); }\n    match /teamMembers/{memberId} {"),
    'M9 timeEntries leggibili dai clienti collegati': ("match /timeEntries/{entryId} {\n        allow read, write: if isProjectOwner(projectId);", "match /timeEntries/{entryId} {\n        allow read, write: if isProjectOwner(projectId) || isLinkedClient(projectId);"),
    'M10 teamMembers leggibili da ogni utente': ("allow read: if signedIn() && resource.data.ownerId == request.auth.uid;\n      allow create: if isAdmin() && request.resource.data.ownerId == request.auth.uid;\n      allow update, delete: if signedIn() && resource.data.ownerId == request.auth.uid;\n    }\n  }", "allow read: if signedIn();\n      allow create: if isAdmin() && request.resource.data.ownerId == request.auth.uid;\n      allow update, delete: if signedIn() && resource.data.ownerId == request.auth.uid;\n    }\n  }"),
}
host = os.environ['FIRESTORE_EMULATOR_HOST']
for i, (nome, (a, b)) in enumerate(MUT.items(), 1):
    if a not in RULES:
        print(f'{nome}: PATTERN NON TROVATO (mutazione non applicabile)'); continue
    proj = f'demo-mut{i}'
    body = json.dumps({'rules': {'files': [{'name': 'firestore.rules', 'content': RULES.replace(a, b, 1)}]}}).encode()
    req = urllib.request.Request(f'http://{host}/emulator/v1/projects/{proj}:securityRules', method='PUT', data=body, headers={'content-type': 'application/json'})
    urllib.request.urlopen(req).read()
    r = subprocess.run(['python3', '-I', '/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/rules_audit.py'], env={**os.environ, 'PROJ': proj}, capture_output=True, text=True)
    ko = [l for l in r.stdout.splitlines() if l.startswith('KO')]
    print(f'{nome}: {"INDIVIDUATA" if ko else "NON INDIVIDUATA"} ({len(ko)} prove rosse)' + (f' es. "{ko[0][3:80].strip()}"' if ko else ''))
