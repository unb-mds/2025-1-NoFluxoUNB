/**
 * Verificação do toque/pan do planejador de formatura.
 * Cada asserção roda em página nova para não haver contaminação entre gestos.
 */
import { chromium, devices } from 'playwright';
const tp=(x,y,id=1)=>({x,y,id,radiusX:10,radiusY:10,force:1});
let falhas=0;
const ok=(c,m)=>{console.log(`  ${c?'✓':'✗'} ${m}`); if(!c)falhas++;};

const browser = await chromium.launch();
async function novaPagina(opts){
  const ctx=await browser.newContext(opts);
  await ctx.addInitScript(()=>localStorage.setItem('nofluxo_anonimo','true'));
  const p=await ctx.newPage(); const cdp=await ctx.newCDPSession(p);
  await p.goto('http://localhost:5199/dev/planner-toque',{waitUntil:'networkidle'});
  await p.waitForSelector('.svelte-flow__node',{timeout:15000});
  await p.waitForTimeout(1200);
  const trans=()=>p.evaluate(()=>document.querySelector('.svelte-flow__viewport').style.transform);
  const ponto=await p.evaluate(()=>{const r=document.querySelector('.planner-flow').getBoundingClientRect();
    return [Math.round(r.x+r.width*0.55), Math.round(Math.min(r.y+r.height-90, innerHeight-90))];});
  return {ctx,p,cdp,trans,ponto};
}

async function metricas(opts,nome){
  const {ctx,p}=await novaPagina(opts);
  const m=await p.evaluate(()=>{const vp=document.querySelector('.svelte-flow__viewport');
    const btn=document.querySelector('.quick-actions button'); const rb=btn?.getBoundingClientRect();
    const c=document.querySelector('[data-subject-code]')?.getBoundingClientRect();
    return {escala:(vp.style.transform.match(/scale\(([\d.]+)\)/)||[0,'1'])[1],
      botao:rb&&rb.width?`${Math.round(rb.width)}x${Math.round(rb.height)}`:'oculto(hover)',
      card:c?`${Math.round(c.width)}x${Math.round(c.height)}`:'n/a'};});
  console.log(`\n=== ${nome} ===\n  métricas:`,m);
  await ctx.close(); return m;
}

async function panDedo(opts){
  const {ctx,p,cdp,trans,ponto}=await novaPagina(opts);
  const a=await trans(); const [x,y]=ponto;
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[tp(x,y)]});
  for(let i=1;i<=12;i++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[tp(x-i*12,y)]});await new Promise(r=>setTimeout(r,16));}
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await p.waitForTimeout(300);
  const r=(await trans())!==a; await ctx.close(); return r;
}
async function pinca(opts){
  const {ctx,p,cdp,trans,ponto}=await novaPagina(opts);
  const a=await trans(); const [x,y]=ponto;
  const par=(d)=>[tp(x-d,y,1),tp(x+d,y,2)];
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:par(30)});
  for(let i=1;i<=10;i++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:par(30+i*8)});await new Promise(r=>setTimeout(r,16));}
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await p.waitForTimeout(300);
  const r=(await trans())!==a; await ctx.close(); return r;
}
async function toqueNoBotao(opts){
  const {ctx,p,cdp}=await novaPagina(opts);
  const btn=p.locator('.quick-actions button',{hasText:'Turmas'}).first();
  const r=await btn.boundingBox();
  if(!r){await ctx.close(); return {altura:0,disparou:false};}
  const bx=Math.round(r.x+r.width/2), by=Math.round(r.y+r.height/2);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[tp(bx,by)]});
  await new Promise(s=>setTimeout(s,80));
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await p.waitForTimeout(500);
  const disparou=(await p.locator('[data-testid="log"]').textContent()).includes('chatAction');
  await ctx.close(); return {altura:Math.round(r.height),disparou};
}
/**
 * `touch-action` do pane e sua posição na árvore.
 *
 * NÃO dá para verificar aqui que o dedo na vertical rola a página: rolagem
 * nativa por toque é decidida no compositor, e nem `Input.dispatchTouchEvent`
 * nem `Input.synthesizeScrollGesture` a acionam neste ambiente — comprovado por
 * controle, um gesto de toque FORA do canvas também não rola, enquanto a roda do
 * mouse rola. O que dá para verificar é o contrato de CSS: o pane precisa
 * computar `pan-y` e ser ancestral dos cards, pois o `touch-action` efetivo de um
 * toque é a interseção da cadeia do elemento atingido até a raiz.
 * O comportamento de rolagem em si precisa de conferência em aparelho real.
 */
async function contratoTouchAction(opts){
  const {ctx,p}=await novaPagina(opts);
  const r=await p.evaluate(()=>{
    const pane=document.querySelector('.svelte-flow__pane');
    const node=document.querySelector('.svelte-flow__node');
    return { touchAction:getComputedStyle(pane).touchAction,
             paneEhAncestralDoCard:pane.contains(node) };
  });
  await ctx.close(); return r;
}

async function panMouseERoda(opts){
  const {ctx,p,trans,ponto}=await novaPagina(opts);
  const [x,y]=ponto; const a=await trans();
  await p.mouse.move(x,y); await p.mouse.down();
  for(let i=1;i<=12;i++){await p.mouse.move(x-i*12,y);await p.waitForTimeout(16);}
  await p.mouse.up(); await p.waitForTimeout(300);
  const pan=(await trans())!==a;
  const sy=await p.evaluate(()=>window.scrollY); const t2=await trans();
  await p.mouse.move(x,y); await p.mouse.wheel(0,300); await p.waitForTimeout(400);
  const rolou=(await p.evaluate(()=>window.scrollY))>sy;
  const canvasParado=(await trans())===t2;
  await ctx.close(); return {pan,rolou,canvasParado};
}

const MOBILE={...devices['Pixel 7']};
const DESKTOP={viewport:{width:1440,height:900}};
const DESKTOP_TOUCH={viewport:{width:1440,height:900},hasTouch:true};

const mM=await metricas(MOBILE,'MOBILE (Pixel 7, 412px)');
ok(Number(mM.escala)>=0.9,`começa em zoom legível (${mM.escala}, antes 0.319 pelo fitView)`);
ok(await panDedo(MOBILE),'arrastar na horizontal move o canvas');
ok(await pinca(MOBILE),'pinça dá zoom');
const v=await contratoTouchAction(MOBILE);
ok(v.touchAction==='pan-y',`pane computa touch-action pan-y, era none (atual: ${v.touchAction})`);
ok(v.paneEhAncestralDoCard,'pane é ancestral dos cards, então o pan-y vale para toques sobre eles');
console.log('  ⚠ a rolagem vertical em si não é verificável por automação — conferir em aparelho real');
const tM=await toqueNoBotao(MOBILE);
ok(tM.altura>=24,`botão do card com altura tocável (${tM.altura}px, antes 9px)`);
ok(tM.disparou,'tocar no botão do card dispara a ação');

await metricas(DESKTOP,'DESKTOP (1440x900, mouse)');
const d=await panMouseERoda(DESKTOP);
ok(d.pan,'arrastar o fundo com o mouse move o canvas (era o bug relatado)');
ok(d.rolou,'a roda do mouse rola a página');
ok(d.canvasParado,'a roda não sequestra o canvas');

await metricas(DESKTOP_TOUCH,'DESKTOP TOUCH (1440x900, hasTouch)');
ok(await panDedo(DESKTOP_TOUCH),'arrastar com o dedo move o canvas');
const tD=await toqueNoBotao(DESKTOP_TOUCH);
ok(tD.disparou,'tocar no botão do card dispara a ação');

await browser.close();
console.log(falhas===0?'\n✅ TODAS AS VERIFICAÇÕES PASSARAM':`\n❌ ${falhas} FALHA(S)`);
process.exit(falhas?1:0);
