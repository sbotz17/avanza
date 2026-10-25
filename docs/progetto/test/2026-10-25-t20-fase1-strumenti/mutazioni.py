import subprocess, sys, re, os
ROOT = '/home/user/avanza/.claude/worktrees/agent-a66f1f7a7de2b0cde/functions'
L = ROOT + '/src/lib/'
muts = [
  ('M1 firma con chiave vuota accettata (hmac.ts: tolto il controllo segreto vuoto)', L+'hmac.ts', "  if (!secret) {\n    return false;\n  }", "  if (false) {\n    return false;\n  }"),
  ('M2 approvazione di "NONE" considerata di fiducia', L+'eventRouter.ts', "['OWNER', 'MEMBER', 'COLLABORATOR']", "['OWNER', 'MEMBER', 'COLLABORATOR', 'NONE']"),
  ('M3 fork non bloccato alla creazione', L+'repoInfo.ts', "if (info.fork) return 'fork';", ""),
  ('M4 progetto eliminato risorge (registro ignorato)', L+'projectCreator.ts', "if (registry.exists) {\n      const state", "if (false && registry.exists) {\n      const state"),
  ('M5 tetto giornaliero fuori di uno (>= diventa >)', L+'projectCreator.ts', "created >= config.maxNewProjectsPerDay", "created > config.maxNewProjectsPerDay"),
  ('M6 proprietario non ammesso accettato', L+'eventProcessor.ts', "if (!config.allowedOwners.includes(repo.ownerLogin)) return", "if (false) return"),
  ('M7 topic avanza-ignora ignorato', L+'repoInfo.ts', "return info.topics.includes(IGNORE_TOPIC);", "return false;"),
  ('M8 interruttore acceso se manca (default on)', L+'linkConfig.ts', "if (data['autoCreateProjects'] !== true) return null;", "if (data['autoCreateProjects'] === false) return null;"),
  ('M9 ID progetto non deterministico', L+'linkStore.ts', "return `gh_${repoId}`;", "return `gh_${repoId}_${Math.random()}`;"),
  ('M10 giorno in UTC invece che ora italiana', L+'linkStore.ts', "timeZone: 'Europe/Rome'", "timeZone: 'UTC'"),
  ('M11 intestatario non verificato admin', L+'projectCreator.ts', "if (!owner.exists || owner.get('role') !== 'admin') return", "if (false) return"),
  ('M12 secondo segreto: provato prima dello storico se esiste (ordine invertito -> source sbagliata)', L+'authenticate.ts', "if (verifySignature(rawBody, signature, primary)) return { ok: true, source: 'webhook' };", "if (verifySignature(rawBody, signature, primary)) return { ok: true, source: 'github-app' };"),
  ('M13 eventi di repository archiviati creano progetto', L+'repoInfo.ts', "if (info.archived) return 'archiviato';", ""),
  ('M14 push di ramo cancellato crea progetto', L+'eventRouter.ts', "p.ref.startsWith('refs/heads/') && p.deleted !== true", "p.ref.startsWith('refs/heads/')"),
  ('M15 mancanza di author_association = fiducia', L+'eventRouter.ts', "review.author_association.toUpperCase() : '';", "review.author_association.toUpperCase() : 'OWNER';"),
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
