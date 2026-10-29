"""Prova delle regole Firestore (firestore.rules di staging) sull'EMULATORE. Mai produzione.
Attori: anon, admin1 (proprietario), admin2 (admin non proprietario), client1 (collegato), client2 (non collegato).
Token finti non firmati (l'emulatore li accetta); 'owner' = bypass delle regole per preparare i dati."""
import base64, json, os, sys, urllib.request, urllib.error

host = os.environ['FIRESTORE_EMULATOR_HOST']
proj = os.environ.get('PROJ', 'demo-avanza')
root = f'http://{host}/v1/projects/{proj}/databases/(default)/documents'
dbname = f'projects/{proj}/databases/(default)/documents'

def b64(d):
    return base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b'=').decode()

def tok(uid):
    return b64({'alg': 'none', 'typ': 'JWT'}) + '.' + b64({'user_id': uid, 'sub': uid, 'aud': proj, 'iss': 'x', 'firebase': {'sign_in_provider': 'password'}}) + '.'

def raw(method, url, token=None, body=None):
    req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body is not None else None)
    req.add_header('content-type', 'application/json')
    if token:
        req.add_header('Authorization', 'Bearer ' + token)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code

def fields(d):
    out = {}
    for k, v in d.items():
        if isinstance(v, bool): out[k] = {'booleanValue': v}
        elif isinstance(v, int): out[k] = {'integerValue': str(v)}
        elif isinstance(v, str): out[k] = {'stringValue': v}
        else: raise ValueError(k)
    return out

def seed(path, d):
    # bypass delle regole con "owner"
    r = raw('PATCH', f'{root}/{path}', 'owner', {'fields': fields(d)})
    assert r == 200, (path, r)

def put(path, d, token):
    return raw('PATCH', f'{root}/{path}', token, {'fields': fields(d)})

def get(path, token):
    return raw('GET', f'{root}/{path}', token)

def delete(path, token):
    return raw('DELETE', f'{root}/{path}', token)

def create(path, d, token, server_ts=None):
    """crea con commit; server_ts = nome del campo valorizzato con request.time"""
    w = {'update': {'name': f'{dbname}/{path}', 'fields': fields(d)}, 'currentDocument': {'exists': False}}
    if server_ts:
        w['updateTransforms'] = [{'fieldPath': server_ts, 'setToServerValue': 'REQUEST_TIME'}]
    return raw('POST', f'http://{host}/v1/projects/{proj}/databases/(default)/documents:commit', token, {'writes': [w]})

def update_commit(path, d, token):
    w = {'update': {'name': f'{dbname}/{path}', 'fields': fields(d)}, 'updateMask': {'fieldPaths': list(d.keys())}, 'currentDocument': {'exists': True}}
    return raw('POST', f'http://{host}/v1/projects/{proj}/databases/(default)/documents:commit', token, {'writes': [w]})

def run_query(parent, coll, token, where_owner=None):
    q = {'structuredQuery': {'from': [{'collectionId': coll}]}}
    if where_owner:
        q['structuredQuery']['where'] = {'fieldFilter': {'field': {'fieldPath': 'ownerId'}, 'op': 'EQUAL', 'value': {'stringValue': where_owner}}}
    url = f'{root}/{parent}:runQuery' if parent else f'{root}:runQuery'
    req = urllib.request.Request(url, method='POST', data=json.dumps(q).encode())
    req.add_header('content-type', 'application/json')
    if token: req.add_header('Authorization', 'Bearer ' + token)
    try:
        with urllib.request.urlopen(req) as r:
            body = json.loads(r.read())
            return 200 if not any('error' in x for x in body) else 403
    except urllib.error.HTTPError as e:
        return e.code

A, A2, C1, C2 = tok('admin1'), tok('admin2'), tok('client1'), tok('client2')
res = []
bad = 0
def check(nome, got, atteso):
    global bad
    ok = (got == 200) == atteso if atteso is not None else True
    # 200 = consentito; 403/401/400 con errore regole = negato
    res.append((nome, got, 'consentito' if atteso else 'NEGATO', 'OK' if ok else 'KO'))
    if not ok: bad += 1

# --- dati di prova (bypass)
seed('users/admin1', {'role': 'admin'}); seed('users/admin2', {'role': 'admin'})
seed('users/client1', {'role': 'client'}); seed('users/client2', {'role': 'client'})
seed('projects/p1', {'ownerId': 'admin1', 'name': 'P1'})
seed('projects/p2', {'ownerId': 'admin2', 'name': 'P2'})
seed('clientAccess/CODE1', {'projectId': 'p1', 'ownerId': 'admin1'})
seed('users/client1/clientProjects/p1', {'code': 'CODE1'})
seed('projects/p1/tasks/t1', {'title': 'T1', 'status': 'active'})
seed('projects/p1/taskCosts/t1', {'estimatedHours': 3})
seed('projects/p1/timeEntries/e1', {'hours': 2})
seed('teamMembers/m1', {'ownerId': 'admin1', 'name': 'M'})
seed('projects/p1/tasks/t1/chat/m0', {'from': 'admin', 'text': 'x'})
seed('githubRepos/1', {'state': 'tracked'})
seed('githubCollegamento/config', {'autoCreateProjects': True})
seed('githubCollegamento/giorno-2026-10-28', {'progettiCreati': 1})

# =============== ONDATA 1: users / clientAccess
check('anon legge users/admin1', get('users/admin1', None), False)
check('admin1 legge il proprio users/admin1', get('users/admin1', A), True)
check('client1 legge users/admin1 (altrui)', get('users/admin1', C1), False)
check('client1 legge il proprio users/client1', get('users/client1', C1), True)
check('client3 crea il proprio profilo con role=client', create('users/client3', {'role': 'client'}, tok('client3')), True)
check('client4 crea il proprio profilo con role=admin (auto-promozione)', create('users/client4', {'role': 'admin'}, tok('client4')), False)
check('client1 crea users/zz (altro uid) con role=client', create('users/zz', {'role': 'client'}, C1), False)
check('client1 modifica il proprio ruolo in admin', put('users/client1?updateMask.fieldPaths=role', {'role': 'admin'}, C1), False)
check('client1 modifica il proprio ruolo in admin (commit)', update_commit('users/client1', {'role': 'admin'}, C1), False)
check('admin1 modifica users/client2 (update)', update_commit('users/client2', {'role': 'admin'}, A), False)
check('admin1 cancella users/client2', delete('users/client2', A), False)
check('anon crea users/anon con role=client', create('users/anon', {'role': 'client'}, None), False)
check('anon legge clientAccess/CODE1', get('clientAccess/CODE1', None), False)
check('client2 legge (get) clientAccess/CODE1', get('clientAccess/CODE1', C2), True)
check('client2 elenca clientAccess (list)', run_query('', 'clientAccess', C2), False)
check('client1 crea clientAccess/NEW', create('clientAccess/NEW', {'projectId': 'p1', 'ownerId': 'client1'}, C1), False)
check('admin1 crea clientAccess/NEW (ownerId=se stesso)', create('clientAccess/NEW', {'projectId': 'p1', 'ownerId': 'admin1'}, A), True)
check('admin1 crea clientAccess/NEW2 con ownerId altrui', create('clientAccess/NEW2', {'projectId': 'p1', 'ownerId': 'admin2'}, A), False)
check('client2 modifica clientAccess/CODE1', update_commit('clientAccess/CODE1', {'projectId': 'p2'}, C2), False)
check('admin2 modifica clientAccess/CODE1 (altrui)', update_commit('clientAccess/CODE1', {'projectId': 'p2'}, A2), False)
check('client2 collega p1 con il codice giusto (users/client2/clientProjects/p1)', create('users/client2/clientProjects/p1', {'code': 'CODE1'}, C2), True)
seed('users/client5', {'role': 'client'})
check('client5 collega p1 con codice SBAGLIATO', create('users/client5/clientProjects/p1', {'code': 'XXXX'}, tok('client5')), False)
check('client5 collega p2 con il codice di p1', create('users/client5/clientProjects/p2', {'code': 'CODE1'}, tok('client5')), False)
check('client5 collega p1 nella cartella di client1 (altro uid)', create('users/client1/clientProjects/p9', {'code': 'CODE1'}, tok('client5')), False)
check('client1 legge clientProjects di client2', get('users/client2/clientProjects/p1', C1), False)
check('client1 modifica il suo collegamento (update)', update_commit('users/client1/clientProjects/p1', {'code': 'CODE1'}, C1), False)
# sessione senza accesso: nessun token
check('anon legge projects/p1', get('projects/p1', None), False)

# =============== ONDATA 2: progetti / task / chat
check('admin1 legge projects/p1', get('projects/p1', A), True)
check('client1 (collegato) legge projects/p1', get('projects/p1', C1), True)
check('client2 (dopo il collegamento) legge projects/p1', get('projects/p1', C2), True)
check('client5 (non collegato) legge projects/p1', get('projects/p1', tok('client5')), False)
check('admin2 (non proprietario) legge projects/p1', get('projects/p1', A2), False)
check('client1 elenca projects senza filtro', run_query('', 'projects', C1), False)
check('client1 elenca projects ownerId=admin1', run_query('', 'projects', C1, 'admin1'), False)
check('admin1 elenca projects ownerId=admin1', run_query('', 'projects', A, 'admin1'), True)
check('admin1 elenca projects ownerId=admin2 (altrui)', run_query('', 'projects', A, 'admin2'), False)
check('client1 crea un progetto (ownerId=se stesso)', create('projects/px', {'ownerId': 'client1', 'name': 'x'}, C1), False)
check('admin1 crea un progetto ownerId=se stesso', create('projects/py', {'ownerId': 'admin1', 'name': 'y'}, A), True)
check('admin1 crea un progetto con ownerId altrui', create('projects/pz', {'ownerId': 'admin2', 'name': 'z'}, A), False)
check('admin2 modifica projects/p1', update_commit('projects/p1', {'name': 'hack'}, A2), False)
check('client1 modifica projects/p1', update_commit('projects/p1', {'name': 'hack'}, C1), False)
check('admin1 modifica projects/p1', update_commit('projects/p1', {'name': 'ok'}, A), True)
check('admin1 legge task t1', get('projects/p1/tasks/t1', A), True)
check('client1 (collegato) legge task t1', get('projects/p1/tasks/t1', C1), True)
check('client5 (non collegato) legge task t1', get('projects/p1/tasks/t1', tok('client5')), False)
check('anon legge task t1', get('projects/p1/tasks/t1', None), False)
check('client1 scrive task t1', update_commit('projects/p1/tasks/t1', {'title': 'hack'}, C1), False)
check('admin1 scrive task t1', update_commit('projects/p1/tasks/t1', {'title': 'ok'}, A), True)
check('admin2 scrive task t1', update_commit('projects/p1/tasks/t1', {'title': 'hack'}, A2), False)
check('client1 cancella task t1', delete('projects/p1/tasks/t1', C1), False)
# chat
check('chat: admin1 legge', get('projects/p1/tasks/t1/chat/m0', A), True)
check('chat: elenco (list) admin1', run_query('projects/p1/tasks/t1', 'chat', A), True)
check('chat: client1 (collegato) legge', get('projects/p1/tasks/t1/chat/m0', C1), False)
check('chat: client1 elenca', run_query('projects/p1/tasks/t1', 'chat', C1), False)
check('chat: admin2 (non proprietario) legge', get('projects/p1/tasks/t1/chat/m0', A2), False)
check('chat: anon legge', get('projects/p1/tasks/t1/chat/m0', None), False)
ok_msg = {'from': 'admin', 'kind': 'domanda', 'text': 'ciao', 'authorUid': 'admin1', 'authorName': 'Andrea'}
check('chat: admin1 crea domanda valida', create('projects/p1/tasks/t1/chat/n1', ok_msg, A, 'createdAt'), True)
check('chat: testo di 2000 caratteri', create('projects/p1/tasks/t1/chat/n2', dict(ok_msg, text='a' * 2000), A, 'createdAt'), True)
check('chat: testo di 2001 caratteri', create('projects/p1/tasks/t1/chat/n3', dict(ok_msg, text='a' * 2001), A, 'createdAt'), False)
check('chat: testo vuoto', create('projects/p1/tasks/t1/chat/n4', dict(ok_msg, text=''), A, 'createdAt'), False)
check('chat: from=squadra', create('projects/p1/tasks/t1/chat/n5', dict(ok_msg, **{'from': 'squadra'}), A, 'createdAt'), False)
check('chat: kind=risposta', create('projects/p1/tasks/t1/chat/n6', dict(ok_msg, kind='risposta'), A, 'createdAt'), False)
check('chat: campo extra', create('projects/p1/tasks/t1/chat/n7', dict(ok_msg, extra='x'), A, 'createdAt'), False)
check('chat: authorUid altrui', create('projects/p1/tasks/t1/chat/n8', dict(ok_msg, authorUid='admin2'), A, 'createdAt'), False)
check('chat: authorName > 200', create('projects/p1/tasks/t1/chat/n9', dict(ok_msg, authorName='a' * 201), A, 'createdAt'), False)
check('chat: createdAt non e request.time (nessun timestamp server)', create('projects/p1/tasks/t1/chat/n10', dict(ok_msg), A), False)
check('chat: createdAt stringa del client', create('projects/p1/tasks/t1/chat/n11', dict(ok_msg, createdAt='2020-01-01'), A), False)
check('chat: client1 crea', create('projects/p1/tasks/t1/chat/n12', ok_msg, C1, 'createdAt'), False)
check('chat: client1 crea con authorUid proprio', create('projects/p1/tasks/t1/chat/n12b', dict(ok_msg, authorUid='client1'), C1, 'createdAt'), False)
check('chat: admin2 (non proprietario) crea', create('projects/p1/tasks/t1/chat/n13', dict(ok_msg, authorUid='admin2'), A2, 'createdAt'), False)
check('chat: anon crea', create('projects/p1/tasks/t1/chat/n14', ok_msg, None, 'createdAt'), False)
check('chat: admin1 modifica m0 (update)', update_commit('projects/p1/tasks/t1/chat/m0', {'text': 'cambiato'}, A), False)
check('chat: admin1 modifica n1 appena creato', update_commit('projects/p1/tasks/t1/chat/n1', {'text': 'cambiato'}, A), False)
check('chat: admin1 cancella m0', delete('projects/p1/tasks/t1/chat/m0', A), False)
check('chat: admin1 cancella n1', delete('projects/p1/tasks/t1/chat/n1', A), False)
check('chat: progetto p2 (di admin2) - admin1 legge', get('projects/p2/tasks/t1/chat/m0', A), False)

# =============== ONDATA 3: squadra e costi
check('taskCosts: admin1 legge', get('projects/p1/taskCosts/t1', A), True)
check('taskCosts: admin1 scrive', update_commit('projects/p1/taskCosts/t1', {'estimatedHours': 5}, A), True)
check('taskCosts: client1 (collegato) legge', get('projects/p1/taskCosts/t1', C1), False)
check('taskCosts: client1 scrive', update_commit('projects/p1/taskCosts/t1', {'estimatedHours': 1}, C1), False)
check('taskCosts: client1 elenca', run_query('projects/p1', 'taskCosts', C1), False)
check('taskCosts: client5 legge', get('projects/p1/taskCosts/t1', tok('client5')), False)
check('taskCosts: admin2 (non proprietario) legge', get('projects/p1/taskCosts/t1', A2), False)
check('taskCosts: anon legge', get('projects/p1/taskCosts/t1', None), False)
check('timeEntries: admin1 legge', get('projects/p1/timeEntries/e1', A), True)
check('timeEntries: client1 (collegato) legge', get('projects/p1/timeEntries/e1', C1), False)
check('timeEntries: client1 elenca', run_query('projects/p1', 'timeEntries', C1), False)
check('timeEntries: client1 scrive', create('projects/p1/timeEntries/e9', {'hours': 1}, C1), False)
check('timeEntries: admin2 (non proprietario) legge', get('projects/p1/timeEntries/e1', A2), False)
check('timeEntries: anon legge', get('projects/p1/timeEntries/e1', None), False)
check('teamMembers: admin1 legge il proprio', get('teamMembers/m1', A), True)
check('teamMembers: admin2 legge quello di admin1', get('teamMembers/m1', A2), False)
check('teamMembers: client1 legge', get('teamMembers/m1', C1), False)
check('teamMembers: client1 elenca', run_query('', 'teamMembers', C1), False)
check('teamMembers: client1 crea (ownerId=se stesso)', create('teamMembers/m2', {'ownerId': 'client1', 'name': 'x'}, C1), False)
check('teamMembers: admin1 crea (ownerId=se stesso)', create('teamMembers/m3', {'ownerId': 'admin1', 'name': 'x'}, A), True)
check('teamMembers: admin1 crea con ownerId altrui', create('teamMembers/m4', {'ownerId': 'admin2', 'name': 'x'}, A), False)
check('teamMembers: anon legge', get('teamMembers/m1', None), False)

# =============== ONDATA 4: collezioni T-20 e collezioni sconosciute
for who, t in (('anon', None), ('client1', C1), ('admin1', A)):
    for path in ('githubRepos/1', 'githubCollegamento/config', 'githubCollegamento/giorno-2026-10-28'):
        check(f'{path}: {who} legge', get(path, t), False)
        check(f'{path}: {who} scrive', update_commit(path, {'x': 'y'}, t), False)
        check(f'{path}: {who} cancella', delete(path, t), False)
    check(f'githubRepos: {who} elenca', run_query('', 'githubRepos', t), False)
    check(f'githubCollegamento: {who} elenca', run_query('', 'githubCollegamento', t), False)
    check(f'collezione sconosciuta /foo/1: {who} legge', get('foo/1', t), False)
    check(f'collezione sconosciuta /foo/1: {who} scrive', create('foo/1', {'a': 'b'}, t), False)

w = max(len(r[0]) for r in res)
for nome, got, att, ok in res:
    print(f'{ok:2} {nome:{w}}  http={got:<4} atteso={att}')
print(f'\nTOTALE prove: {len(res)}  difformi dall\'atteso: {bad}')
sys.exit(1 if bad else 0)
