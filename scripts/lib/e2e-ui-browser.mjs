// Aiuti per pilotare Flutter web (CanvasKit) con Playwright, usati da scripts/e2e-ui-test.mjs.
// Flutter disegna su un canvas: i controlli diventano elementi DOM (<flt-semantics>) solo dopo "Enable accessibility".
// Per questo si usano ruoli, etichette accessibili (aria-label) e testi, con attese esplicite.
// Nessuna dipendenza: `getPage` restituisce la pagina Playwright corrente.

const pausa = (ms) => new Promise((r) => setTimeout(r, ms));
export const escAttr = (s) => String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"');

export function creaAiuti(getPage, { msg = (e) => String(e?.message ?? e) } = {}) {
  const P = () => getPage();

  /** Testo a schermo: nel contenuto del nodo oppure nell'etichetta accessibile (Flutter unisce spesso piu' testi in una sola etichetta). */
  function testo(t, { esatto = false } = {}) {
    return P()
      .getByText(t, { exact: esatto })
      .or(P().locator(esatto ? `[aria-label="${escAttr(t)}"]` : `[aria-label*="${escAttr(t)}"]`));
  }

  function bottone(nome) {
    return P()
      .getByRole('button', { name: nome, exact: true })
      .or(P().locator(`[role="button"][aria-label="${escAttr(nome)}"]`));
  }

  function campo(etichetta) {
    const e = escAttr(etichetta);
    return P()
      .locator(`input[aria-label="${e}"], textarea[aria-label="${e}"]`)
      .or(P().getByRole('textbox', { name: etichetta, exact: true }));
  }

  /** La chat e' l'unico campo di testo della pagina del task: nome accessibile se c'e', altrimenti l'ultimo campo di testo. */
  function campoChat() {
    return P()
      .getByRole('textbox', { name: /Chiedi alla squadra/i })
      .or(P().locator('textarea, input[type="text"], [role="textbox"]'))
      .last();
  }

  async function aspetta(loc, ms = 20000) {
    await loc.first().waitFor({ state: 'attached', timeout: ms });
  }

  /** Click robusto: normale, poi forzato (il canvas puo' sovrapporsi), poi evento DOM. */
  async function clicca(loc) {
    const el = loc.first();
    await el.waitFor({ state: 'attached', timeout: 15000 });
    try {
      await el.click({ timeout: 4000 });
      return;
    } catch {
      /* si prova il click forzato */
    }
    try {
      await el.click({ timeout: 4000, force: true });
      return;
    } catch {
      /* si prova l'evento DOM */
    }
    await el.dispatchEvent('click');
  }

  /** Valore dell'<input>/<textarea> reale dentro (o al posto di) l'elemento; null se non c'e' (non verificabile). */
  async function leggiValore(loc) {
    return loc.first().evaluate((el) => {
      const i = el.matches('input,textarea') ? el : el.querySelector('input,textarea');
      return i ? i.value : null;
    });
  }

  /**
   * Scrive nel campo con la tastiera vera e VERIFICA che il testo arrivato sia identico: Flutter ogni tanto perde dei caratteri
   * se si scrive troppo in fretta (visto in prova: 2 caratteri persi su 31). Tre strategie: tastiera veloce, tastiera lenta, fill.
   * Il valore non viene mai registrato: negli errori compaiono solo le lunghezze.
   */
  async function scrivi(loc, valore) {
    const strategie = [{ delay: 20 }, { delay: 70 }, { fill: true }];
    let ultimo = '';
    for (const s of strategie) {
      try {
        await clicca(loc);
        await P().keyboard.press('Control+A');
        await P().keyboard.press('Delete');
        if (s.fill) await loc.first().fill(valore, { timeout: 5000 });
        else await P().keyboard.type(valore, { delay: s.delay });
        await pausa(150);
        const letto = await leggiValore(loc);
        if (letto === null || letto === valore) return;
        ultimo = `lunghezza letta ${letto.length}, attesa ${valore.length}`;
      } catch (e) {
        ultimo = `errore: ${msg(e)}`;
      }
    }
    throw new Error(`Il testo scritto nel campo non coincide con quello atteso dopo 3 tentativi (${ultimo}).`);
  }

  async function valoreCampo(etichetta) {
    const loc = campo(etichetta).first();
    await loc.waitFor({ state: 'attached', timeout: 15000 });
    return loc.evaluate((el) => {
      const i = el.matches('input,textarea') ? el : el.querySelector('input,textarea');
      return i ? i.value : el.getAttribute('aria-valuetext') || el.getAttribute('value') || '';
    });
  }

  async function finoA(condizione, ms, descrizione) {
    const fine = Date.now() + ms;
    let ultimo;
    while (Date.now() < fine) {
      try {
        const r = await condizione();
        if (r) return r;
      } catch (e) {
        ultimo = e;
      }
      await pausa(400);
    }
    throw new Error(`Timeout (${ms} ms): ${descrizione}${ultimo ? ` (${msg(ultimo)})` : ''}`);
  }

  /** Abilita l'albero semantico di Flutter ("Enable accessibility"), se non lo e' gia'. */
  async function abilitaSemantica() {
    const page = P();
    await page.locator('flt-glass-pane').first().waitFor({ state: 'attached', timeout: 90000 });
    if ((await page.locator('flt-semantics').count()) === 0) {
      const ph = page.locator('flt-semantics-placeholder').first();
      try {
        await ph.waitFor({ state: 'attached', timeout: 15000 });
        await ph.dispatchEvent('click');
      } catch {
        /* forse gia' attiva: si controlla sotto */
      }
      if ((await page.locator('flt-semantics').count()) === 0) await ph.evaluate((el) => el.click()).catch(() => {});
    }
    await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 20000 });
    await pausa(500);
  }

  /** Testi presenti a schermo (etichette accessibili e contenuti): per la diagnostica e per cercare errori visibili. */
  async function leggiSchermata(max = 90) {
    return P()
      .evaluate((m) => {
        const out = new Set();
        document.querySelectorAll('flt-semantics').forEach((el) => {
          const t = (el.getAttribute('aria-label') || el.textContent || '').trim().replace(/\s+/g, ' ');
          if (t) out.add(t.slice(0, m));
        });
        return [...out].slice(0, 80);
      }, max)
      .catch(() => []);
  }

  return { testo, bottone, campo, campoChat, aspetta, clicca, scrivi, valoreCampo, finoA, abilitaSemantica, leggiSchermata, pausa };
}
