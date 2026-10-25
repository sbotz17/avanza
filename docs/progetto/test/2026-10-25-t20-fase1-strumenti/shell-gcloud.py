import os, subprocess, tempfile, yaml
ROOT = '/home/user/avanza/.claude/worktrees/agent-a66f1f7a7de2b0cde'
d = yaml.safe_load(open(ROOT + '/.github/workflows/imposta-segreto-app.yml'))
script = [s for s in d['jobs']['imposta']['steps'] if 'Scrivi il segreto' in s.get('name', '')][0]['run']
SECRET = 'SEGRETO-DI-PROVA-' + 'k' * 30

FAKE = r'''#!/usr/bin/env bash
# gcloud finto: stato in $FAKE_DIR
D="$FAKE_DIR"
case "$*" in
  "secrets describe"*) [ -f "$D/exists" ] && exit 0; echo "ERROR: NOT_FOUND: Secret not found" >&2; exit 1;;
  "secrets create"*) [ "$FAKE_CREATE_FAIL" = 1 ] && { echo "ERROR: PERMISSION_DENIED" >&2; exit 1; }; touch "$D/exists"; exit 0;;
  "secrets versions add"*) [ "$FAKE_ADD_FAIL" = 1 ] && { echo "ERROR: PERMISSION_DENIED" >&2; exit 1; }; cat > "$D/value"; exit 0;;
  "secrets versions access"*) [ "$FAKE_READ_FAIL" = 1 ] && { echo "ERROR: PERMISSION_DENIED on access" >&2; exit 1; }; [ -f "$D/value" ] || exit 1; if [ "$FAKE_READ_DIFF" = 1 ]; then printf 'altro'; else cat "$D/value"; fi; exit 0;;
esac
echo "gcloud finto: comando non previsto: $*" >&2; exit 2
'''

def run(label, env, pre=None, expect=0):
    fd = tempfile.mkdtemp(); bd = tempfile.mkdtemp()
    open(bd + '/gcloud', 'w').write(FAKE); os.chmod(bd + '/gcloud', 0o755)
    if pre:
        pre(fd)
    e = {'PATH': bd + ':' + os.environ['PATH'], 'HOME': '/root', 'FAKE_DIR': fd, 'AMBIENTE': 'produzione', 'NOME_SEGRETO': 'GITHUB_APP_WEBHOOK_SECRET',
         'PROGETTO': 'avanza-b62d7', 'VALORE_PROD': SECRET, 'VALORE_TEST': ''}
    e.update(env)
    p = subprocess.run(['bash', '-e', '-c', script], env=e, capture_output=True, text=True)
    out = p.stdout + p.stderr
    leak = SECRET in out
    print(('OK ' if p.returncode == expect and not leak else 'KO!') + f' {label}: rc={p.returncode} (atteso {expect}) segreto_nel_log={leak} | ' + out.strip().replace('\n', ' | ')[:200])

run('segreto inesistente -> creato, versione aggiunta, riletto', {})
def ex(fd): open(fd + '/exists', 'w').close(); open(fd + '/value', 'w').write(SECRET)
run('segreto gia\' con lo stesso valore -> nessuna nuova versione', {}, ex)
def ex2(fd): open(fd + '/exists', 'w').close(); open(fd + '/value', 'w').write('vecchio')
run('segreto con valore diverso -> nuova versione', {}, ex2)
run('creazione negata -> errore con istruzioni', {'FAKE_CREATE_FAIL': '1'}, None, 1)
run('aggiunta versione negata -> errore', {'FAKE_ADD_FAIL': '1'}, None, 1)
run('rilettura negata -> errore', {'FAKE_READ_FAIL': '1'}, ex2, 1)
run('valore riletto diverso -> errore', {'FAKE_READ_DIFF': '1'}, ex, 1)
run('valore con a capo finale (copia/incolla)', {'VALORE_PROD': SECRET + '\n'})
run('test: usa il valore di test, non quello di produzione', {'AMBIENTE': 'test', 'VALORE_PROD': 'DA-NON-USARE-' + 'z' * 30, 'VALORE_TEST': SECRET})
