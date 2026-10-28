import { launch, openApp, shot, semText, log, currentPath, login, waitPath } from './common.mjs';
import { listDocs } from './emu.mjs';
import fs from 'fs';
const ids = JSON.parse(fs.readFileSync(new URL('./ids.json', import.meta.url)));
const dir = '/tmp/claude-0/-home-user/a4a389bf-77be-5d81-ac7f-0c1bb199291a/scratchpad/e2e/prof-t3';
fs.rmSync(dir, { recursive: true, force: true });
const { ctx, page } = await launch(dir, { width: 390, height: 780 });
await openApp(page);
await login(page, 'cliente2@test.it', ids.PW);
await waitPath(page, /client-home/, 25000);
await page.waitForTimeout(2000);
const code = page.locator('input[aria-label^="Codice progetto"]');
for (const c of ['ZZZZZZ', 'ABC', 'SEC999']) {
  await code.click(); await page.keyboard.press('Control+A'); await page.keyboard.insertText(c); await page.waitForTimeout(300);
  await page.getByRole('button', { name: 'Collega', exact: true }).click(); await page.waitForTimeout(3000);
  const t = await semText(page, 3000);
  const links = (await listDocs(`users/${ids.cli2}/clientProjects`)).map((l) => l.id);
  console.log(c, '=> UI:', (t.split('|').pop() || '').slice(0, 220).replace(/\n/g, ' '), '| collegamenti:', JSON.stringify(links));
  await shot(page, 't3-codice-' + c);
}
await ctx.close();
