// Pure transition logic shared by the verified-session worker and regression checks.
export function normalizeDensity(value){return typeof value==='number'&&Number.isFinite(value)?Math.max(30,Math.min(95,Math.round(value))):64;}
export function normalizeBlur(value){return typeof value==='number'&&Number.isFinite(value)?Math.max(0,Math.min(20,Math.round(value))):4;}
export async function reconcile({state,snapshot,evaluate,apply,restore}){
  if(snapshot.url!=='app://-/index.html')throw Error('Renderer navigated away from official app');
  if(!state.enabled){
    if(snapshot.active){const result=await evaluate(restore);if(!result?.restored)throw Error('Could not remove glass');}
    return {status:'off'};
  }
  if(!snapshot.ready)return {status:'waiting',reason:'Native panels are loading'};
  const density=normalizeDensity(state.density);
  const blur=normalizeBlur(state.blur);
  let actualDensity=snapshot.density;
  let actualBlur=snapshot.blur;
  if(!snapshot.active||snapshot.version!==snapshot.expectedVersion){
    const result=await evaluate(apply);
    if(!result?.applied)throw Error('Glass apply did not succeed');
    actualDensity=result.density;
    actualBlur=result.blur;
  }
  if(actualDensity!==density){const result=await evaluate(`window.__CODEX_DREAM_GLASS__.setDensity(${density})`);if(result!==density)throw Error('Glass density update failed');}
  if(actualBlur!==blur){const result=await evaluate(`window.__CODEX_DREAM_GLASS__.setBlur(${blur})`);if(result!==blur)throw Error('Glass blur update failed');}
  const proof=await evaluate(`(() => ({active:!!window.__CODEX_DREAM_GLASS__&&!!document.getElementById('codex-dream-glass-style')&&document.documentElement.dataset.codexDreamGlass==='true',version:window.__CODEX_DREAM_GLASS__?.version,density:window.__CODEX_DREAM_GLASS__?.density,blur:window.__CODEX_DREAM_GLASS__?.blur}))()`);
  if(!proof?.active||proof.version!==snapshot.expectedVersion)throw Error('Glass activation check failed');
  if(proof.density!==density)throw Error('Glass density verification failed');
  if(proof.blur!==blur)throw Error('Glass blur verification failed');
  return {status:'on',version:proof.version,density,blur};
}
