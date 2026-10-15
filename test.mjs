import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const {chromium}=require('/home/jordan/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const browser=await chromium.launch({executablePath:'/home/jordan/.cache/ms-playwright/chromium-1148/chrome-linux/chrome',headless:true,args:['--no-sandbox']});
const context=await browser.newContext({viewport:{width:1024,height:1366},deviceScaleFactor:1});
const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
// Render the code-native SVG icon at the exact manifest sizes.
for(const size of [192,512]){await page.setViewportSize({width:size,height:size});await page.goto('http://127.0.0.1:4173/assets/icon.svg');await page.screenshot({path:`public/assets/icon-${size}.png`});}
await page.setViewportSize({width:1024,height:1366});await page.goto('http://127.0.0.1:4173');
await page.screenshot({path:'/tmp/insieme-ipad.png',fullPage:true});
const {lessons}=await import('./public/content.js');
for(let l=0;l<4;l++){
 await page.locator(`.mission[data-lesson="${l}"]`).click();
 for(let s=0;s<4;s++){
  const item=lessons[l].steps[s];
  if(item.interaction==='inspect'){for(const part of ['hp','attack','retreat'])await page.locator(`[data-inspect="${part}"]`).click();}
  else {
   if(l===0&&s===0){await page.locator('[data-choice="1"]').click();if(await page.locator('[data-action="lesson-next"]').isEnabled())throw Error('Wrong answer advanced');}
   await page.locator(`[data-choice="${item.answer}"]`).click();
  }
  await page.locator('[data-action="lesson-next"]').click();
 }
 await page.locator('.brand').click();
}
await page.reload();if(await page.locator('.mission-num').allTextContents().then(a=>a.filter(x=>x==='✓').length)!==4)throw Error('Progress did not persist');
await page.locator('[data-page="practice"]').first().click();
for(let i=0;i<9;i++){
 if(i===2){await page.locator('[data-action="practice-wrong"]').click();if(!await page.locator('#toast').isVisible())throw Error('Missing feedback');}
 if(i===6){await page.screenshot({path:'/tmp/insieme-practice.png',fullPage:true});const count=await page.locator('.practice-card:not(.ee) .energy').count();if(count!==2)throw Error('Energy did not persist across turns');}
 await page.locator('[data-action="practice-next"]').click();
}
if(!await page.getByText('Avete giocato un giro completo!').isVisible())throw Error('Practice did not finish');
await page.locator('[data-page="table"]').first().click();
for(let i=0;i<6;i++)await page.locator(`[data-check="${i}"]`).check();
await page.locator('[data-action="start-table"]').click();
for(let phase=0;phase<4;phase++){const count=await page.locator('[data-check]').count();for(let i=0;i<count;i++)await page.locator(`[data-check="${i}"]`).check();await page.locator('[data-action="table-next"]').click();}
if(!await page.getByText('Giocatore B',{exact:true}).isVisible())throw Error('Did not switch player');
await page.locator('[data-page="guide"]').click();await page.locator('#search').fill('retreat');if(await page.locator('.rule').count()<1)throw Error('Bilingual search failed');
await page.locator('#search').fill('xyzzy');if(!await page.getByText('Nessun risultato.',{exact:false}).isVisible())throw Error('Empty search failed');
await page.locator('[data-action="install"]').click();if(!await page.locator('dialog').isVisible())throw Error('Install instructions failed');await page.locator('[data-action="close-modal"]').click();
await page.locator('.brand').click();
for(const [width,height] of [[820,1180],[1180,820],[390,844]]){await page.setViewportSize({width,height});for(const nav of ['home','practice','table','guide']){await page.locator(`.nav[data-page="${nav}"]`).click();if(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth))throw Error(`Overflow on ${nav} at ${width}`);} }
await page.locator('.brand').click();await page.screenshot({path:'/tmp/insieme-mobile.png',fullPage:true});
// A fresh context loads the now-complete icon set and verifies the service worker.
const offlineContext=await browser.newContext();const offlinePage=await offlineContext.newPage();await offlinePage.goto('http://127.0.0.1:4173');await offlinePage.evaluate(()=>navigator.serviceWorker.ready);await offlinePage.reload();await offlineContext.setOffline(true);await offlinePage.reload();await offlinePage.locator('[data-lesson="0"]').last().click();if(!await offlinePage.getByText('Una squadra, insieme.',{exact:true}).isVisible())throw Error('Offline lesson failed');
if(errors.length)throw Error(errors.join('\n'));
console.log('PASS: all 16 lesson steps, wrong-answer gating, saved progress, 9 practice steps, Energy persistence, table turn transitions, bilingual search, dialogs, responsive layouts, and offline lesson loading.');
await browser.close();
