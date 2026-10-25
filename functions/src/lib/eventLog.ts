import { logger } from 'firebase-functions/v2';
import { EventSource } from './types';

/**
 * Registro strutturato degli eventi GitHub (T-20): ogni evento firmato lascia una traccia ricercabile in Cloud Logging
 * (jsonPayload), compresi quelli non agganciati o scartati. Niente dati personali: solo nome pubblico del repository,
 * tipo di evento, esito, motivo, codice task. Niente titoli, messaggi di commit, email.
 */
export type Outcome = 'aggiornato' | 'creato' | 'non_agganciato' | 'scartato' | 'escluso' | 'ignorato';

export interface EventLogEntry {
  outcome: Outcome;
  reason: string;
  eventType: string;
  source: EventSource;
  repo?: string;
  delivery?: string;
  projectId?: string;
  taskCode?: string;
}

/** Id di consegna di GitHub (uuid): si tiene solo se ha la forma attesa. */
export function cleanDelivery(value: unknown): string {
  return typeof value === 'string' && /^[0-9A-Za-z-]{1,64}$/.test(value) ? value : '-';
}

export function logEvent(entry: EventLogEntry): void {
  const message = `github-evento ${entry.outcome}: ${entry.reason}`;
  const data = { ...entry };
  if (entry.outcome === 'scartato' && entry.reason === 'proprietario_config_non_valido') logger.error(message, data);
  else if (entry.outcome === 'scartato') logger.warn(message, data);
  else logger.info(message, data);
}
