"""Scenari di shell dei due workflow: si estrae il testo `run:` dei passi dal YAML e lo si esegue con variabili finte. Mai gcloud reale."""
import os, subprocess, tempfile, textwrap, yaml, shutil, sys

ROOT = os.environ.get('ROOTWF', '/home/user/avanza/.claude/worktrees/agent-a66f1f7a7de2b0cde')

def step(wf, name_part):
    d = yaml.safe_load(open(f'{ROOT}/.github/workflows/{wf}'))
    for job in d['jobs'].values():
        for s in job['steps']:
            if name_part in s.get('name', ''):
                return s['run']
    raise SystemExit('passo non trovato ' + name_part)

def sh(script, env, cwd):
    e = {'PATH': os.environ['PATH'], 'HOME': os.environ.get('HOME', '/root'), 'GITHUB_OUTPUT': os.path.join(cwd, 'out.txt')}
    e.update(env)
    open(e['GITHUB_OUTPUT'], 'w').close()
    p = subprocess.run(['bash', '-e', '-c', script], cwd=cwd, env=e, capture_output=True, text=True)
    return p.returncode, (p.stdout + p.stderr).strip().replace('\n', ' | ')[:230]

res = []
def check(label, got, expect):
    ok = 'OK ' if got == expect else 'KO!'
    res.append(f'{ok} {label}: rc={got} (atteso {expect})')

# ---------- registra-ore.yml: guardia collegamento ----------
g = step('registra-ore.yml', 'Controlli delle azioni collegamento')
base = {'RIF': 'refs/heads/main', 'BLOCCO_VAR': '', 'BUCKET': 'bucket', 'NOTA': 'attiva'}
cases = [
    ('attiva da main con bucket', {}, 0),
    ('attiva da staging', {'RIF': 'refs/heads/staging'}, 1),
    ('attiva da ramo feature', {'RIF': 'refs/heads/feature/T-20-x'}, 1),
    ('attiva con RIF finto "refs/heads/main2"', {'RIF': 'refs/heads/main2'}, 1),
    ('attiva con BLOCCO_SQUADRA=ATTIVO', {'BLOCCO_VAR': 'ATTIVO'}, 1),
    ('attiva senza bucket', {'BUCKET': ''}, 1),
    ('riammetti senza bucket', {'BUCKET': '', 'NOTA': 'riammetti'}, 1),
    ('riammetti con blocco', {'BLOCCO_VAR': 'ATTIVO', 'NOTA': 'riammetti'}, 1),
    ('ATTIVA maiuscolo senza bucket', {'BUCKET': '', 'NOTA': 'ATTIVA'}, 1),
    ('nota vuota senza bucket (azione sconosciuta -> comunque bloccata)', {'BUCKET': '', 'NOTA': ''}, 1),
    ('spegni da main con blocco e senza bucket (freno di emergenza)', {'BLOCCO_VAR': 'ATTIVO', 'BUCKET': '', 'NOTA': 'spegni'}, 0),
    ('"  Spegni " con spazi e maiuscola', {'BLOCCO_VAR': 'ATTIVO', 'BUCKET': '', 'NOTA': '  Spegni '}, 0),
    ('spegni da staging (ramo non main)', {'RIF': 'refs/heads/staging', 'NOTA': 'spegni'}, 1),
    ('spegni da ramo feature con blocco', {'RIF': 'refs/heads/feature/x', 'BLOCCO_VAR': 'ATTIVO', 'NOTA': 'spegni'}, 1),
    ('nota "spegni attiva" (iniezione) senza bucket', {'BUCKET': '', 'NOTA': 'spegni attiva'}, 1),
    ('nota "spegni\\nattiva" senza bucket', {'BUCKET': '', 'NOTA': 'spegni\nattiva'}, 1),
    ('nota con $(...) non eseguita', {'NOTA': 'attiva$(touch /tmp/PWNED_T20)'}, 0),
]
d = tempfile.mkdtemp()
for label, over, exp in cases:
    env = dict(base); env.update(over)
    rc, out = sh(g, env, d)
    check('registra-ore/' + label, rc, exp)
check('registra-ore/nessun comando iniettato eseguito', int(os.path.exists('/tmp/PWNED_T20')), 0)
# file di blocco nel repository
d2 = tempfile.mkdtemp(); open(d2 + '/BLOCCO-SQUADRA.md', 'w').write('ATTIVO\nmotivo')
check('registra-ore/attiva con BLOCCO-SQUADRA.md ATTIVO', sh(g, base, d2)[0], 1)
check('registra-ore/spegni con BLOCCO-SQUADRA.md ATTIVO e senza bucket', sh(g, dict(base, BUCKET='', NOTA='spegni'), d2)[0], 0)
d3 = tempfile.mkdtemp(); open(d3 + '/BLOCCO-SQUADRA.md', 'w').write('SPENTO\n')
check('registra-ore/attiva con BLOCCO-SQUADRA.md non attivo', sh(g, base, d3)[0], 0)

# ---------- imposta-segreto-app.yml: controlli iniziali ----------
c = step('imposta-segreto-app.yml', 'Controlli prima di toccare')
os.makedirs('/tmp/fakebin', exist_ok=True)
# copia reale dello script salvavita, richiamato con percorso relativo dal passo
dd = tempfile.mkdtemp()
os.makedirs(dd + '/.claude/scripts')
shutil.copy(ROOT + '/.claude/scripts/salvavita-test.sh', dd + '/.claude/scripts/salvavita-test.sh')
long = 'x' * 40
B = {'AMBIENTE': 'produzione', 'PROGETTO_PROD': 'avanza-b62d7', 'PROGETTO_TEST': 'avanza-test-c33ef', 'NOME_SEGRETO': 'GITHUB_APP_WEBHOOK_SECRET',
     'RIF': 'refs/heads/main', 'BLOCCO_VAR': '', 'SA_TEST': '', 'SA_PROD': '{"project_id":"avanza-b62d7"}', 'VALORE_PROD': long, 'VALORE_TEST': ''}
sc = [
    ('prod da main con tutto', {}, 0),
    ('prod da staging', {'RIF': 'refs/heads/staging'}, 1),
    ('prod con BLOCCO', {'BLOCCO_VAR': 'ATTIVO'}, 1),
    ('prod senza SA', {'SA_PROD': ''}, 1),
    ('prod senza valore', {'VALORE_PROD': ''}, 1),
    ('prod con valore da 31 caratteri', {'VALORE_PROD': 'x' * 31}, 1),
    ('prod con valore da 32 caratteri', {'VALORE_PROD': 'x' * 32}, 0),
    ('prod: solo il valore di TEST presente (non deve ripiegare)', {'VALORE_PROD': '', 'VALORE_TEST': long}, 1),
    ('test con valore di test', {'AMBIENTE': 'test', 'SA_TEST': '{"project_id":"avanza-test-c33ef"}', 'SA_PROD': '', 'VALORE_PROD': '', 'VALORE_TEST': long}, 0),
    ('test: solo il valore di PRODUZIONE presente (non deve ripiegare)', {'AMBIENTE': 'test', 'SA_TEST': '{"project_id":"avanza-test-c33ef"}', 'SA_PROD': '', 'VALORE_PROD': long, 'VALORE_TEST': ''}, 1),
    ('test con chiave di servizio che e\' della produzione', {'AMBIENTE': 'test', 'SA_TEST': '{"project_id":"avanza-b62d7"}', 'SA_PROD': '', 'VALORE_PROD': '', 'VALORE_TEST': long}, 1),
    ('test con PROGETTO_TEST = produzione', {'AMBIENTE': 'test', 'PROGETTO_TEST': 'avanza-b62d7', 'SA_TEST': '{"project_id":"x"}', 'SA_PROD': '', 'VALORE_PROD': '', 'VALORE_TEST': long}, 1),
    ('test da qualsiasi ramo (staging)', {'AMBIENTE': 'test', 'RIF': 'refs/heads/staging', 'SA_TEST': '{"project_id":"avanza-test-c33ef"}', 'SA_PROD': '', 'VALORE_PROD': '', 'VALORE_TEST': long}, 0),
]
if not shutil.which('jq'):
    res.append('NOTA: jq assente in questo ambiente: i casi con SA_TEST usano il ramo senza jq')
for label, over, exp in sc:
    env = dict(B); env.update(over)
    rc, out = sh(c, env, dd)
    check('imposta-segreto/' + label, rc, exp)
    if rc == 0 and 'segreto GitHub' in out:
        assert long not in out and 'x' * 32 not in out, 'SEGRETO NEL LOG'
dd2 = tempfile.mkdtemp(); os.makedirs(dd2 + '/.claude/scripts'); shutil.copy(ROOT + '/.claude/scripts/salvavita-test.sh', dd2 + '/.claude/scripts/salvavita-test.sh')
open(dd2 + '/BLOCCO-SQUADRA.md', 'w').write('ATTIVO\n')
check('imposta-segreto/prod con BLOCCO-SQUADRA.md ATTIVO', sh(c, B, dd2)[0], 1)
print('\n'.join(res))
