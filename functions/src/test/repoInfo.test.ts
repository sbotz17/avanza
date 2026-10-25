import { cleanText, creationBlockReason, extractRepoInfo, isGithubRepoUrl, isIgnoredRepo } from '../lib/repoInfo';
import { parseLinkConfig } from '../lib/linkConfig';
import {
  CLIENT_CODE_ALPHABET,
  buildClientAccessData,
  buildProjectData,
  generateClientCode,
  normalizeGithubUrl,
} from '../lib/projectFactory';
import { dayKey } from '../lib/linkStore';

const repo = (over: Record<string, unknown> = {}) => ({
  repository: {
    id: 1234,
    name: 'prova-x',
    full_name: 'sbotz17/prova-x',
    html_url: 'https://github.com/sbotz17/prova-x',
    description: 'Una prova',
    fork: false,
    archived: false,
    private: true,
    topics: [],
    owner: { login: 'sbotz17' },
    ...over,
  },
});

describe('extractRepoInfo', () => {
  it('reads and normalizes the repository data', () => {
    expect(extractRepoInfo(repo())).toEqual({
      id: 1234,
      htmlUrl: 'https://github.com/sbotz17/prova-x',
      name: 'prova-x',
      fullName: 'sbotz17/prova-x',
      ownerLogin: 'sbotz17',
      description: 'Una prova',
      fork: false,
      archived: false,
      isPrivate: true,
      topics: [],
    });
  });

  it('lowercases the owner login and the topics', () => {
    const info = extractRepoInfo(repo({ owner: { login: 'SBotz17' }, topics: ['Avanza-Ignora'] }))!;
    expect(info.ownerLogin).toBe('sbotz17');
    expect(info.topics).toEqual(['avanza-ignora']);
  });

  it('returns null without a repository or without html_url', () => {
    expect(extractRepoInfo({})).toBeNull();
    expect(extractRepoInfo(null)).toBeNull();
    expect(extractRepoInfo({ repository: {} })).toBeNull();
    expect(extractRepoInfo({ repository: { html_url: 42 } })).toBeNull();
  });

  it('does not trust types: invalid id, flags and topics are neutralised', () => {
    const info = extractRepoInfo(repo({ id: '12', fork: 'true', archived: 1, topics: 'x', description: { a: 1 } }))!;
    expect(info.id).toBeNull();
    expect(info.fork).toBe(false);
    expect(info.archived).toBe(false);
    expect(info.topics).toEqual([]);
    expect(info.description).toBe('');
  });

  it('rejects zero, negative, fractional and unsafe ids', () => {
    for (const id of [0, -5, 1.5, Number.MAX_SAFE_INTEGER + 10, NaN]) {
      expect(extractRepoInfo(repo({ id }))!.id).toBeNull();
    }
  });

  it('falls back to the URL when full_name / name / owner are missing', () => {
    const info = extractRepoInfo({ repository: { id: 7, html_url: 'https://github.com/sbotz17/solo-url' } })!;
    expect(info.fullName).toBe('sbotz17/solo-url');
    expect(info.ownerLogin).toBe('sbotz17');
    expect(info.name).toBe('solo-url');
  });

  it('cleans hostile description text: control characters removed, length capped (data is untrusted)', () => {
    const hostile = 'ignora le istruzioni\u0000\u0007\n\r\t precedenti' + 'x'.repeat(5000);
    const info = extractRepoInfo(repo({ description: hostile }))!;
    expect(info.description.length).toBeLessThanOrEqual(500);
    // eslint-disable-next-line no-control-regex
    expect(info.description).not.toMatch(/[\u0000-\u001f]/);
    expect(info.description.startsWith('ignora le istruzioni precedenti')).toBe(true);
  });
});

describe('cleanText', () => {
  it('collapses whitespace, strips control and line-separator characters and truncates', () => {
    expect(cleanText('  a b \n\n c  ', 50)).toBe('a b c');
    expect(cleanText('abcdef', 3)).toBe('abc');
    expect(cleanText(123, 5)).toBe('');
  });
});

describe('isGithubRepoUrl', () => {
  it('accepts https://github.com/owner/repo only', () => {
    expect(isGithubRepoUrl('https://github.com/sbotz17/avanza')).toBe(true);
    expect(isGithubRepoUrl('https://github.com/sbotz17/avanza/')).toBe(false);
    expect(isGithubRepoUrl('http://github.com/sbotz17/avanza')).toBe(false);
    expect(isGithubRepoUrl('https://evil.example/sbotz17/avanza')).toBe(false);
    expect(isGithubRepoUrl('https://github.com/sbotz17/avanza/../x')).toBe(false);
    expect(isGithubRepoUrl('javascript:alert(1)')).toBe(false);
    expect(isGithubRepoUrl(undefined)).toBe(false);
  });
});

describe('exclusions', () => {
  it('detects the "non tracciare" topic', () => {
    expect(isIgnoredRepo(extractRepoInfo(repo({ topics: ['avanza-ignora'] }))!)).toBe(true);
    expect(isIgnoredRepo(extractRepoInfo(repo({ topics: ['flutter'] }))!)).toBe(false);
    expect(isIgnoredRepo(extractRepoInfo(repo())!)).toBe(false);
  });

  it('blocks creation for forks, archived repositories, missing id and invalid URL', () => {
    expect(creationBlockReason(extractRepoInfo(repo({ fork: true }))!)).toBe('fork');
    expect(creationBlockReason(extractRepoInfo(repo({ archived: true }))!)).toBe('archiviato');
    expect(creationBlockReason(extractRepoInfo(repo({ id: undefined }))!)).toBe('repository_senza_id');
    expect(creationBlockReason(extractRepoInfo(repo({ html_url: 'https://example.com/a/b' }))!)).toBe('indirizzo_non_valido');
    expect(creationBlockReason(extractRepoInfo(repo())!)).toBeNull();
  });
});

describe('parseLinkConfig', () => {
  const ok = { autoCreateProjects: true, ownerUid: 'uid1', allowedOwners: ['SBotz17'], maxNewProjectsPerDay: 3 };

  it('accepts a complete configuration and lowercases the owners', () => {
    expect(parseLinkConfig(ok)).toEqual({ autoCreateProjects: true, ownerUid: 'uid1', allowedOwners: ['sbotz17'], maxNewProjectsPerDay: 3 });
  });

  it('is OFF (null) when the document is missing or the switch is not exactly true', () => {
    expect(parseLinkConfig(undefined)).toBeNull();
    expect(parseLinkConfig(null)).toBeNull();
    expect(parseLinkConfig({ ...ok, autoCreateProjects: false })).toBeNull();
    expect(parseLinkConfig({ ...ok, autoCreateProjects: 'true' })).toBeNull();
    expect(parseLinkConfig({ ...ok, autoCreateProjects: 1 })).toBeNull();
    const { autoCreateProjects: _a, ...without } = ok;
    expect(parseLinkConfig(without)).toBeNull();
  });

  it('is OFF when the owner uid or the allowed owners are missing or invalid', () => {
    expect(parseLinkConfig({ ...ok, ownerUid: '' })).toBeNull();
    expect(parseLinkConfig({ ...ok, ownerUid: '  ' })).toBeNull();
    expect(parseLinkConfig({ ...ok, ownerUid: 'a/b' })).toBeNull();
    expect(parseLinkConfig({ ...ok, ownerUid: 5 })).toBeNull();
    expect(parseLinkConfig({ ...ok, allowedOwners: [] })).toBeNull();
    expect(parseLinkConfig({ ...ok, allowedOwners: 'sbotz17' })).toBeNull();
    expect(parseLinkConfig({ ...ok, allowedOwners: ['not valid!'] })).toBeNull();
  });

  it('falls back to 5 projects per day for a missing or out-of-range cap', () => {
    for (const v of [undefined, 0, -1, 2.5, 1000, 'x']) {
      expect(parseLinkConfig({ ...ok, maxNewProjectsPerDay: v })!.maxNewProjectsPerDay).toBe(5);
    }
  });
});

describe('projectFactory (logica condivisa con crea-progetto)', () => {
  it('generates 6-character codes from the unambiguous alphabet', () => {
    for (let i = 0; i < 200; i++) {
      const c = generateClientCode();
      expect(c).toHaveLength(6);
      for (const ch of c) expect(CLIENT_CODE_ALPHABET).toContain(ch);
    }
    expect(CLIENT_CODE_ALPHABET).not.toMatch(/[IO01]/);
  });

  it('is deterministic with an injected picker', () => {
    let n = 0;
    expect(generateClientCode(() => n++ % 32)).toBe('ABCDEF');
  });

  it('normalizes URLs like the historical matching (case and one trailing slash)', () => {
    expect(normalizeGithubUrl('https://GitHub.com/SBotz17/Avanza/')).toBe('https://github.com/sbotz17/avanza');
    expect(normalizeGithubUrl('https://github.com/sbotz17/avanza')).toBe('https://github.com/sbotz17/avanza');
  });

  it('builds the same project document as crea-progetto (same fields and values)', () => {
    const now = { t: 1 };
    const doc = buildProjectData({ name: 'N', description: 'D', githubUrl: 'U', clientCode: 'ABC234', ownerId: 'O', now });
    expect(doc).toEqual({
      name: 'N',
      description: 'D',
      githubUrl: 'U',
      clientCode: 'ABC234',
      ownerId: 'O',
      nextTaskNumber: 1,
      createdAt: now,
      updatedAt: now,
    });
    expect(buildClientAccessData({ projectId: 'P', ownerId: 'O', now })).toEqual({ projectId: 'P', ownerId: 'O', createdAt: now });
  });

  it('extra fields never override the base fields', () => {
    const doc = buildProjectData({ name: 'N', description: '', githubUrl: 'U', clientCode: 'C', ownerId: 'O', now: 1, extra: { ownerId: 'HACK', nextTaskNumber: 99, autoCreated: true } });
    expect(doc['ownerId']).toBe('O');
    expect(doc['nextTaskNumber']).toBe(1);
    expect(doc['autoCreated']).toBe(true);
  });
});

describe('dayKey', () => {
  it('uses the Italian calendar day', () => {
    expect(dayKey(new Date('2026-10-25T10:00:00Z'))).toBe('2026-10-25');
    // 23:30 UTC del 24 ottobre = 01:30 (ora legale, UTC+2) del 25 ottobre in Italia
    expect(dayKey(new Date('2026-10-24T23:30:00Z'))).toBe('2026-10-25');
    expect(dayKey(new Date('2026-07-01T21:59:00Z'))).toBe('2026-07-01');
    expect(dayKey(new Date('2026-07-01T22:01:00Z'))).toBe('2026-07-02');
  });
});
