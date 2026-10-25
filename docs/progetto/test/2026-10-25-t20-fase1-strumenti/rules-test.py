import base64, json, os, urllib.request, urllib.error
host = os.environ['FIRESTORE_EMULATOR_HOST']
proj = 'demo-avanza'
base = f'http://{host}/v1/projects/{proj}/databases/(default)/documents'

def b64(d):
    return base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b'=').decode()

def tok(uid):
    return b64({'alg': 'none', 'typ': 'JWT'}) + '.' + b64({'user_id': uid, 'sub': uid, 'aud': proj, 'iss': 'x', 'firebase': {'sign_in_provider': 'password'}}) + '.'

def call(method, path, token=None, body=None):
    req = urllib.request.Request(base + path, method=method, data=json.dumps(body).encode() if body is not None else None)
    req.add_header('content-type', 'application/json')
    if token:
        req.add_header('Authorization', 'Bearer ' + token)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code

# dati di prova (bypass delle regole con "owner")
call('PATCH', '/users/admin1?updateMask.fieldPaths=role', 'owner', {'fields': {'role': {'stringValue': 'admin'}}})
call('PATCH', '/users/client1?updateMask.fieldPaths=role', 'owner', {'fields': {'role': {'stringValue': 'client'}}})
call('PATCH', '/githubCollegamento/config?updateMask.fieldPaths=autoCreateProjects', 'owner', {'fields': {'autoCreateProjects': {'booleanValue': True}}})
call('PATCH', '/githubRepos/1?updateMask.fieldPaths=state', 'owner', {'fields': {'state': {'stringValue': 'tracked'}}})
call('PATCH', '/githubCollegamento/giorno-2026-10-25?updateMask.fieldPaths=progettiCreati', 'owner', {'fields': {'progettiCreati': {'integerValue': '3'}}})

actors = {'senza accesso': None, 'cliente (client1)': tok('client1'), 'admin (admin1)': tok('admin1')}
targets = ['/githubCollegamento/config', '/githubCollegamento/giorno-2026-10-25', '/githubRepos/1']
bad = 0
for who, t in actors.items():
    for path in targets:
        r_get = call('GET', path, t)
        r_patch = call('PATCH', path + '?updateMask.fieldPaths=x', t, {'fields': {'x': {'stringValue': 'y'}}})
        r_del = call('DELETE', path, t)
        print(f'{who:20} {path:42} get={r_get} scrittura={r_patch} cancellazione={r_del}')
        if r_get == 200 or r_patch == 200 or r_del == 200:
            bad += 1
    for coll in ['/githubCollegamento', '/githubRepos']:
        r = call('GET', coll, t)
        print(f'{who:20} elenco {coll:34} list={r}')
        if r == 200:
            bad += 1
print('VIOLAZIONI:', bad)
# controllo di sanita': l'admin legge il proprio documento (regola esistente) e il bypass "owner" funziona
print('sanita admin legge users/admin1:', call('GET', '/users/admin1', tok('admin1')), '| cliente legge users/admin1:', call('GET', '/users/admin1', tok('client1')), '| owner legge config:', call('GET', '/githubCollegamento/config', 'owner'))
