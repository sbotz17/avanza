import { RepoInfo } from './types';

/** Argomento (topic) GitHub con cui Andrea marca un repository "non tracciare" (T-20, CA-7.1). */
export const IGNORE_TOPIC = 'avanza-ignora';

const GITHUB_REPO_URL = /^https:\/\/github\.com\/[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/;

/**
 * Toglie i caratteri di controllo e quelli invisibili o bidirezionali (zero-width U+200B-200F, separatori U+2028-202E,
 * isolati bidi U+2066-206F, U+2060-2064, soft hyphen U+00AD, BOM U+FEFF, annotazioni U+FFF9-FFFB), comprime gli spazi e taglia.
 * Il testo che arriva da GitHub e' DATO NON FIDATO e si salva solo come testo semplice: niente caratteri che ne nascondano
 * o ne invertano la lettura.
 */
const INVISIBLE = /[\u0000-\u001f\u007f-\u009f\u00ad\u200b-\u200f\u2028-\u202e\u2060-\u2064\u2066-\u206f\ufeff\ufff9-\ufffb]/g;
export function cleanText(value: unknown, max: number): string {
  if (typeof value !== 'string') return '';
  return value.replace(INVISIBLE, ' ').replace(/\s+/g, ' ').trim().slice(0, max);
}

/** true se e' un indirizzo del tipo https://github.com/<proprietario>/<repository>. */
export function isGithubRepoUrl(url: unknown): url is string {
  return typeof url === 'string' && url.length <= 200 && GITHUB_REPO_URL.test(url);
}

/**
 * Ricava i dati del repository da un payload GitHub, senza fidarsi dei tipi.
 * Restituisce null se manca l'indirizzo del repository.
 */
export function extractRepoInfo(payload: unknown): RepoInfo | null {
  const repo = (payload as { repository?: Record<string, unknown> } | null | undefined)?.repository;
  if (!repo || typeof repo !== 'object') return null;
  const htmlUrl = repo['html_url'];
  if (typeof htmlUrl !== 'string' || htmlUrl.length === 0) return null;

  const rawId = repo['id'];
  const id = typeof rawId === 'number' && Number.isSafeInteger(rawId) && rawId > 0 ? rawId : null;

  const owner = repo['owner'] as { login?: unknown } | undefined;
  const fullNameRaw = typeof repo['full_name'] === 'string' ? (repo['full_name'] as string) : '';
  const fromUrl = htmlUrl.replace(/^https?:\/\/github\.com\//i, '');
  const fullName = cleanText(fullNameRaw || fromUrl, 140);
  const ownerLogin = cleanText(
    typeof owner?.login === 'string' ? owner.login : fullName.split('/')[0] ?? '',
    60
  ).toLowerCase();
  const name = cleanText(typeof repo['name'] === 'string' ? repo['name'] : fullName.split('/')[1] ?? '', 100);

  const topicsRaw = repo['topics'];
  const topics = Array.isArray(topicsRaw)
    ? topicsRaw.filter((t): t is string => typeof t === 'string').map((t) => t.toLowerCase())
    : [];

  return {
    id,
    htmlUrl,
    name,
    fullName,
    ownerLogin,
    description: cleanText(repo['description'], 500),
    fork: repo['fork'] === true,
    archived: repo['archived'] === true,
    isPrivate: repo['private'] === true,
    topics,
  };
}

/** Repository marcato "non tracciare" (topic `avanza-ignora`): non si crea e non si aggiorna nulla. */
export function isIgnoredRepo(info: RepoInfo): boolean {
  return info.topics.includes(IGNORE_TOPIC);
}

/** Motivo per cui un repository NON puo' dare origine a un progetto nuovo (indipendente da configurazione e tetti), oppure null. */
export function creationBlockReason(
  info: RepoInfo
): 'fork' | 'archiviato' | 'repository_senza_id' | 'indirizzo_non_valido' | null {
  if (info.fork) return 'fork';
  if (info.archived) return 'archiviato';
  if (info.id === null) return 'repository_senza_id';
  if (!isGithubRepoUrl(info.htmlUrl) || info.name.length === 0) return 'indirizzo_non_valido';
  return null;
}

/**
 * Coerenza del proprietario (T-20, D1): `owner.login`, `full_name` e `html_url` devono indicare lo stesso proprietario
 * (e lo stesso nome di repository). Un payload incoerente non puo' far nascere un progetto: il controllo sul proprietario
 * ammesso si farebbe su un campo mentre l'indirizzo salvato punterebbe altrove.
 */
export function ownerIsConsistent(info: RepoInfo): boolean {
  const m = /^https:\/\/github\.com\/([^/]+)\/([^/]+)$/i.exec(info.htmlUrl);
  if (!m) return false;
  const [urlOwner, urlName] = [m[1].toLowerCase(), m[2].toLowerCase()];
  const [fullOwner, fullName] = info.fullName.toLowerCase().split('/');
  return (
    info.ownerLogin !== '' &&
    info.ownerLogin === urlOwner &&
    info.ownerLogin === fullOwner &&
    fullName === urlName &&
    info.name.toLowerCase() === urlName
  );
}
