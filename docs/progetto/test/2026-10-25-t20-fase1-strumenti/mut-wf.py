import os, shutil, subprocess
S = '/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad'
R = '/home/user/avanza/.claude/worktrees/agent-a66f1f7a7de2b0cde'
src = open(S + '/shell-wf.py').read()
src = src.replace("ROOT = '/home/user/avanza/.claude/worktrees/agent-a66f1f7a7de2b0cde'", "ROOT = os.environ.get('ROOTWF', '/home/user/avanza/.claude/worktrees/agent-a66f1f7a7de2b0cde')")
open(S + '/shell-wf.py', 'w').write(src)
muts = [
 ('S1 registra-ore: controllo ramo main tolto', 'registra-ore.yml', 'if [ "$RIF" != "refs/heads/main" ]; then\n            echo "::error::Le azioni collegamento', 'if false; then\n            echo "::error::Le azioni collegamento'),
 ('S2 registra-ore: bucket non richiesto', 'registra-ore.yml', 'if [ -z "$BUCKET" ]; then', 'if false; then'),
 ('S3 registra-ore: BLOCCO_SQUADRA ignorato', 'registra-ore.yml', 'if [ "$BLOCCO_VAR" = "ATTIVO" ]; then echo "::error::BLOCCO_SQUADRA attivo: azione sospesa"; exit 1; fi', 'true'),
 ('S4 registra-ore: spegni non esentato', 'registra-ore.yml', 'if [ "$NOTA_MIN" != "spegni" ]; then', 'if true; then'),
 ('S5 imposta-segreto: lunghezza minima tolta', 'imposta-segreto-app.yml', 'if [ "${#VALORE}" -lt 32 ]; then', 'if false; then'),
 ('S6 imposta-segreto: ramo main tolto', 'imposta-segreto-app.yml', 'if [ "$RIF" != "refs/heads/main" ]; then', 'if false; then'),
 ('S7 imposta-segreto: ripiego su valore di test per produzione', 'imposta-segreto-app.yml', 'VALORE="$VALORE_PROD"; NOME_GH="GH_APP_WEBHOOK_SECRET"', 'VALORE="${VALORE_PROD:-$VALORE_TEST}"; NOME_GH="GH_APP_WEBHOOK_SECRET"'),
]
for name, f, old, new in muts:
    d = '/tmp/mutwf-' + name[:2]
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d + '/.github/workflows'); os.makedirs(d + '/.claude/scripts')
    shutil.copy(R + '/.claude/scripts/salvavita-test.sh', d + '/.claude/scripts/')
    for w in ('registra-ore.yml', 'imposta-segreto-app.yml'):
        shutil.copy(R + '/.github/workflows/' + w, d + '/.github/workflows/')
    p = d + '/.github/workflows/' + f
    s = open(p).read()
    if old not in s:
        print(name, 'ANCORA NON TROVATA'); continue
    open(p, 'w').write(s.replace(old, new, 1))
    o = subprocess.run(['python3', '-I', S + '/shell-wf.py'], env={**os.environ, 'ROOTWF': d}, capture_output=True, text=True)
    ko = [l for l in o.stdout.splitlines() if l.startswith('KO')]
    print(name, '=>', 'CATTURATA' if ko else 'NON CATTURATA', len(ko), 'scenari KO', o.stderr[-120:] if o.returncode else '')
