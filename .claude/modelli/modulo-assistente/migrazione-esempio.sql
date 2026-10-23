-- =====================================================================================
-- MODULO ASSISTENTE - schema dati di base (Supabase / PostgreSQL)
-- Provato su PostgreSQL 16 con ruoli e funzione auth.uid() simulati (vedi test descritti in SPECIFICA.md).
-- Modello di partenza: il dba lo adatta al progetto e lo mette in supabase/migrations/.
-- Solo AGGIUNTE: nessuna tabella esistente viene toccata. Le segnalazioni non si modificano e non si
-- cancellano (append-only): lo stato di una segnalazione e' l'ultimo evento registrato.
-- =====================================================================================

-- 1) Segnalazioni di MALFUNZIONAMENTO (e solo quelle). Immutabili dopo l'invio.
--    Non esiste un tipo "richiesta" o "suggerimento": questa sezione NON raccoglie richieste di nuove funzioni.
--    Descrizione, passi e comportamento atteso sono obbligatori: obbligano a descrivere un malfunzionamento concreto.
--    La gravita' NON la dichiara l'utente (si presta ad abusi): la valuta la squadra dopo la verifica.
create table public.segnalazioni (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid references auth.users(id) on delete set null,   -- se l'utente viene eliminato, la segnalazione resta anonima
  titolo           text not null check (char_length(titolo) between 3 and 200),
  descrizione      text not null check (char_length(descrizione) between 10 and 3000),  -- cosa e' successo
  passi            text not null check (char_length(passi) between 5 and 2000),         -- cosa stava facendo, passo per passo
  atteso           text not null check (char_length(atteso) between 3 and 1000),        -- cosa si aspettava che succedesse
  versione_app     text check (char_length(versione_app) <= 40),
  piattaforma      text check (char_length(piattaforma) <= 40),
  created_at       timestamptz not null default now()
);
create index on public.segnalazioni (user_id, created_at desc);

-- 2) Eventi di stato (solo aggiunte). L'utente li legge; li scrive solo il sistema (service_role).
--    I messaggi pubblici NON sono testo libero: li compone la funzione di sistema da modelli fissi + titolo di un argomento del manuale.
create table public.segnalazioni_eventi (
  id                uuid primary key default gen_random_uuid(),
  segnalazione_id   uuid not null references public.segnalazioni(id) on delete restrict,
  tipo              text not null check (tipo in (
                      'ricevuta',              -- inviata
                      'presa_in_carico',       -- la squadra sta verificando
                      'non_riproducibile',     -- verificato: il malfunzionamento non si presenta
                      'uso_scorretto',       -- verificato: nessun malfunzionamento, la funzione va usata in altro modo (rimando al manuale)
                      'fuori_ambito',          -- non e' un malfunzionamento (es. richiesta di una nuova funzione): non viene sviluppato nulla
                      'duplicata',             -- gia' segnalato da altri
                      'corretta_in_sviluppo',  -- malfunzionamento confermato e corretto, in attesa di rilascio
                      'rilasciata',            -- correzione in produzione
                      'chiusa')),
  messaggio_pubblico text check (char_length(messaggio_pubblico) <= 600),   -- da modelli fissi: MAI dati personali, MAI testo dell'utente
  argomento_manuale text,                                                   -- per 'uso_scorretto': argomento del manuale da leggere
  ritorno_id        text,                                                   -- riferimento interno della squadra (es. R-42)
  versione          text,                                                   -- versione in cui e' stato risolto
  created_at        timestamptz not null default now()
);
create index on public.segnalazioni_eventi (segnalazione_id, created_at desc);

-- 3) Sezione "Novita e problemi risolti": visibile a tutti gli utenti, scritta solo dal sistema.
create table public.aggiornamenti (
  id             uuid primary key default gen_random_uuid(),
  tipo           text not null check (tipo in ('novita','problema_risolto','avviso')),
  titolo         text not null check (char_length(titolo) between 3 and 200),
  testo          text not null check (char_length(testo) <= 4000),          -- niente dati personali
  versione       text,
  pubblicato_il  timestamptz not null default now()
);
create index on public.aggiornamenti (pubblicato_il desc);

-- 4) Ogni nuova segnalazione registra da sola l'evento "ricevuta".
create function public.segnalazione_ricevuta() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.segnalazioni_eventi (segnalazione_id, tipo, messaggio_pubblico)
  values (new.id, 'ricevuta', 'Abbiamo ricevuto la tua segnalazione.');
  return new;
end $$;
create trigger trg_segnalazione_ricevuta after insert on public.segnalazioni
  for each row execute function public.segnalazione_ricevuta();

-- 5) Anti-abuso: massimo 10 segnalazioni per utente all'ora.
create function public.limita_segnalazioni() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.segnalazioni
       where user_id = new.user_id and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'Troppe segnalazioni in poco tempo, riprova piu tardi' using errcode = 'P0001';
  end if;
  return new;
end $$;
create trigger trg_limita_segnalazioni before insert on public.segnalazioni
  for each row execute function public.limita_segnalazioni();

-- 6) Vista per l'utente: le sue segnalazioni con l'ultimo stato (rispetta le regole RLS di chi la interroga).
create view public.le_mie_segnalazioni with (security_invoker = true) as
select s.id, s.titolo, s.created_at,
       e.tipo as stato, e.messaggio_pubblico, e.argomento_manuale, e.versione, e.created_at as stato_aggiornato_il
from public.segnalazioni s
left join lateral (
  select tipo, messaggio_pubblico, argomento_manuale, versione, created_at
  from public.segnalazioni_eventi where segnalazione_id = s.id
  order by created_at desc limit 1
) e on true;

-- 7) Sicurezza: RLS su tutto e privilegi minimi.
alter table public.segnalazioni         enable row level security;
alter table public.segnalazioni_eventi  enable row level security;
alter table public.aggiornamenti        enable row level security;

revoke all on public.segnalazioni, public.segnalazioni_eventi, public.aggiornamenti, public.le_mie_segnalazioni from anon, authenticated;
grant select, insert on public.segnalazioni        to authenticated;
grant select         on public.segnalazioni_eventi to authenticated;
grant select         on public.aggiornamenti       to authenticated;
grant select         on public.le_mie_segnalazioni to authenticated;

-- Il sistema (service_role) puo' solo leggere e AGGIUNGERE: neppure lui puo' modificare o cancellare righe gia' scritte.
revoke all on public.segnalazioni, public.segnalazioni_eventi, public.aggiornamenti from service_role;
grant select         on public.segnalazioni         to service_role;
grant select, insert on public.segnalazioni_eventi  to service_role;
grant select, insert on public.aggiornamenti        to service_role;

create policy segnalazioni_lettura_proprie on public.segnalazioni
  for select to authenticated using (user_id = auth.uid());
create policy segnalazioni_inserimento_proprie on public.segnalazioni
  for insert to authenticated with check (user_id = auth.uid());
-- nessuna policy di update/delete: le segnalazioni non si modificano ne' si cancellano.

create policy eventi_lettura_propri on public.segnalazioni_eventi
  for select to authenticated using (
    exists (select 1 from public.segnalazioni s where s.id = segnalazione_id and s.user_id = auth.uid()));
-- nessuna policy di insert: gli eventi li scrive solo il sistema con service_role (che ignora RLS).

create policy aggiornamenti_lettura on public.aggiornamenti
  for select to authenticated using (true);
