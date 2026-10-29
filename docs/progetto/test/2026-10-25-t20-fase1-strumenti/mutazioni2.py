import subprocess, sys, re, os
ROOT = '/home/user/avanza/.claude/worktrees/agent-a66f1f7a7de2b0cde/functions'
L = ROOT + '/src/lib/'
muts = [
  ('N1 D1 creazione consentita anche dal webhook storico', L+'eventProcessor.ts', "if (source !== 'github-app') return", "if (false) return"),
  ('N2 D1 controllo coerenza proprietario tolto', L+'eventProcessor.ts', "if (!ownerIsConsistent(repo)) return", "if (false) return"),
  ('N3 D1 coerenza: full_name non confrontato con owner', L+'repoInfo.ts', "info.ownerLogin === fullOwner &&", ""),
  ('N4 D1 coerenza: URL non confrontato con owner', L+'repoInfo.ts', "info.ownerLogin === urlOwner &&", ""),
  ('N5 D3 codice 9 (versione disabilitata) non gestito', L+'secrets.ts', "if (code === 5 || code === 9) return null;", "if (code === 5) return null;"),
  ('N6 D3 NOT_FOUND non gestito', L+'secrets.ts', "if (code === 5 || code === 9) return null;", "if (code === 9) return null;"),
  ('N7 D3 qualsiasi errore = assente (fail-open)', L+'secrets.ts', "if (code === 5 || code === 9) return null;", "return null;"),
]
only = sys.argv[1:]
res = []
for name, path, old, new in muts:
    if only and not any(name.startswith(o+' ') for o in only): continue
    src = open(path, encoding='utf8').read()
    if old not in src:
        res.append((name, 'ANCORA NON TROVATA')); continue
    open(path, 'w', encoding='utf8').write(src.replace(old, new, 1))
    try:
        subprocess.run(['npx','tsc','--noEmit'], cwd=ROOT, capture_output=True)
        p = subprocess.run(['npx','jest','--silent'], cwd=ROOT, capture_output=True, text=True, timeout=300)
        out = p.stdout + p.stderr
        m = re.search(r'Tests:\s+(.*)', out)
        failed = re.findall(r'●\s+(.*)', out)
        files = sorted(set(re.findall(r'FAIL (\S+)', out)))
        res.append((name, ('CATTURATA' if p.returncode != 0 else 'NON CATTURATA') + ' | ' + (m.group(1) if m else '?') + ' | file: ' + ','.join(files)))
    finally:
        open(path, 'w', encoding='utf8').write(src)
for r in res: print(r[0], '=>', r[1])
