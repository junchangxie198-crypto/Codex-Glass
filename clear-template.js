((css) => {
  if(location.href !== 'app://-/index.html' || typeof css !== 'string' || !css.includes('--dg-ink')) throw Error('Invalid glass target or payload');
  if(!document.querySelector('aside.app-shell-left-panel,.ProseMirror[contenteditable="true"]')) throw Error('Native panels missing; current appearance preserved');
  const key='__CODEX_DREAM_GLASS__',root=document.documentElement;
  window[key]?.dispose();
  const style=document.createElement('style');style.id='codex-dream-glass-style';style.textContent=css;document.head.append(style);
  const materials=new Map(),texts=new Map(),layouts=new Map(),codeOverrides=new Map(),surfaceOverrides=new Map(),visible=new Set(),pendingRoots=new Set();
  const canvas=document.createElement('canvas');canvas.width=32;canvas.height=20;
  const ctx=canvas.getContext('2d',{willReadFrequently:true});
  const sampleInterval=1000,workDelay=140;
  let disposed=false,workTimer=null,sampleTimer=null,idleHandle=null;
  let currentScheme=null,smoothed=null,candidate=null,candidateCount=0;
  const stats={version:'3.6.14',density:64,blur:4,samples:0,updates:0,lastSampleAt:0,lastError:null,mean:null,discoveryPasses:0,processedRoots:0,textPasses:0,repairedText:0,workTotalMs:0,maxWorkMs:0,sampleTotalMs:0};
  const densityBefore={value:root.style.getPropertyValue('--dg-density-shift'),priority:root.style.getPropertyPriority('--dg-density-shift'),attr:root.getAttribute('data-dg-density')};
  const blurBefore={value:root.style.getPropertyValue('--dg-blur'),priority:root.style.getPropertyPriority('--dg-blur'),attr:root.getAttribute('data-dg-blur')};
  function setBlur(value){const number=Number(value);if(!Number.isFinite(number))throw Error('Invalid glass blur');stats.blur=Math.max(0,Math.min(20,Math.round(number)));root.style.setProperty('--dg-blur',stats.blur+'px');root.dataset.dgBlur=String(stats.blur);return stats.blur;}
  function setDensity(value){
    const number=Number(value);if(!Number.isFinite(number))throw Error('Invalid glass density');
    stats.density=Math.max(30,Math.min(95,Math.round(number)));
    root.style.setProperty('--dg-density-shift',((stats.density-64)/100).toFixed(2));root.dataset.dgDensity=String(stats.density);
    return stats.density;
  }
  const structural='#root,.thread-scroll-container,[data-app-shell-page-surface],[data-app-shell-frame],[class*="_Workspace_"],[class*="_PageSurfaceLayout_"]';
  const settingsPanel='[class~="group/settings"] [style*="--color-background-panel"]';
  const settingsControl='[class~="group/settings"] :is(button[aria-haspopup],input:not([type="checkbox"]):not([type="radio"]):not([type="range"]):not([type="hidden"]),select,textarea)';
  const settingsIcon='aside.app-shell-left-panel [data-settings-panel-slug] svg';
  const chatgptMessage='[data-chatgpt-search-unit-key$=":assistant"]';
  const assistantMarkdown='[data-markdown-text-style="assistant-message"]';
  const chatgptControl='[class*="_ComposerLayoutRoot_"] [class~="bg-(--composer-layout-surface-background)"]';
  const chatgptIcon='[data-talvt-turn-state] button svg';
  const sidebarLayer='aside.app-shell-left-panel .sidebar-navigation,aside.app-shell-left-panel nav[class*="_Navigation_"]';
  const sidebarRail='aside.app-shell-left-panel nav[class~="group/sidebar-rail"]';
  const pageHeader='[class*="_shell_"]:has(> [class*="_content_"] [class*="_headerRow_"])';
  const pageSurface='div[class~="bg-surface"]:has([data-testid="sites-grid"]),div[class~="bg-surface"]:has(> [data-profile-scroll])';
  const homeComposerBody='[data-composer-utility-bar-variant="home"] > [data-composer-body]';
  const composerTools='[data-composer-utility-rail][data-composer-rail-placement="above"]';
  const extraSurfaces=pageHeader+','+sidebarRail+','+pageSurface+','+homeComposerBody+','+composerTools+',[class~="group/site-card"]';
  const resourceRow='button[class~="bg-surface/70"]';
  const selectors='[class*="_ApplicationMenuTopBar_"],aside.app-shell-left-panel,.app-shell-right-panel,[class*="_ComposerLayoutRoot_"],.bg-user-message,[class~="group/agent-activity"],[data-local-conversation-final-assistant],[class~="group/summary-panel"],header,[role="dialog"],[role="menu"],[role="listbox"],[role="tooltip"],[data-radix-menu-content],[data-cws-surface="panel"],[data-cws-surface="elevated"],[data-slot="card"],div[class*="rounded"][class*="bg-surface"],[data-code-block],pre,'+sidebarLayer+','+resourceRow+','+settingsPanel+','+settingsControl+','+settingsIcon+','+chatgptMessage+','+assistantMarkdown+','+chatgptControl+','+chatgptIcon;
  const skipped='script,style,svg,pre,code,.sr-only,[disabled],[aria-disabled="true"],.text-codex-git-added,.text-codex-git-deleted';
  function ownAttr(el,name,value){const old=el.getAttribute(name);if(old!==value)el.setAttribute(name,value);return old;}
  function restoreAttr(el,name,old){if(old===null)el.removeAttribute(name);else el.setAttribute(name,old);}
  function restoreText(el,old){restoreAttr(el,'data-dream-glass-text',old.attr);if(/^var\(--dg-(?:ink|muted|link)\)$/.test(el.style.getPropertyValue('color'))){if(old.color)el.style.setProperty('color',old.color,old.priority);else el.style.removeProperty('color');}}
  function inWallpaper(el){return el.closest('#codex-wallpaper-skin-host');}
  function codeScheme(el){const block=el.closest('[data-code-block]')||el;return block.classList.contains('dark')?'dark':block.classList.contains('light')?'light':getComputedStyle(root).colorScheme.includes('dark')?'dark':'light';}
  function restoreCode(el,old){for(const[name,value]of old){if(value.value)el.style.setProperty(name,value.value,value.priority);else el.style.removeProperty(name);}}
  function fixCode(el){for(const code of el.querySelectorAll('[data-code-block-source] code')){if(codeOverrides.has(code))continue;const old=new Map();for(const[name,value]of [['white-space','pre-wrap'],['overflow-wrap','anywhere'],['word-break','normal']]){old.set(name,{value:code.style.getPropertyValue(name),priority:code.style.getPropertyPriority(name)});code.style.setProperty(name,value,'important');}codeOverrides.set(code,old);}}
  function fixSurface(el,transparent=false){
    if(surfaceOverrides.has(el))return;
    const name='background-color',value=el.matches(sidebarRail)?'rgba(var(--dg-rgb),var(--dg-rail-alpha,0))':transparent?'rgba(var(--dg-rgb),var(--dg-peek-alpha,0))':'rgba(var(--dg-rgb),var(--dg-alpha))';
    const old={value:el.style.getPropertyValue(name),priority:el.style.getPropertyPriority(name),attr:ownAttr(el,'data-dg-surface','true')};
    // Native important cascade layers outrank unlayered stylesheet rules.
    // Keep background and text on the same adaptive palette, with exact rollback.
    el.style.setProperty(name,value,'important');
    old.applied=el.style.getPropertyValue(name);surfaceOverrides.set(el,old);
  }
  function restoreSurface(el,old){restoreAttr(el,'data-dg-surface',old.attr);if(el.style.getPropertyValue('background-color')!==old.applied)return;if(old.value)el.style.setProperty('background-color',old.value,old.priority);else el.style.removeProperty('background-color');}
  function fixControl(el){
    fixSurface(el);fixForeground(el);
  }
  function fixForeground(el){
    if(!texts.has(el)){texts.set(el,{attr:el.getAttribute('data-dream-glass-text'),color:el.style.getPropertyValue('color'),priority:el.style.getPropertyPriority('color')});el.dataset.dreamGlassText='primary';el.style.setProperty('color','var(--dg-ink)','important');}
  }
  function tag(el,kind){
    if(materials.has(el)||inWallpaper(el))return;
    if(el.matches(structural)||(kind==='card'&&el.querySelector('.ProseMirror[contenteditable="true"],.thread-scroll-container,[data-thread-scroll-footer]'))){if(!layouts.has(el))layouts.set(el,ownAttr(el,'data-dream-glass-layout','true'));return;}
    if(kind==='card'&&el.parentElement?.closest('[data-dream-glass]')&&!el.matches('[data-slot="card"],div[class*="rounded"][class*="bg-surface"],[class~="group/site-card"]'))return;
    materials.set(el,{kind,material:ownAttr(el,'data-dream-glass',kind),scheme:el.getAttribute('data-dream-glass-scheme'),inview:el.getAttribute('data-dg-inview')});
    el.dataset.dreamGlassScheme=kind==='codeblock'||kind==='code'?codeScheme(el):(currentScheme||'dark');
    if(kind==='sidebar'||kind==='popup'||kind==='settings'||kind==='header'||kind==='rail'||kind==='page'||kind==='composer'||kind==='composer-tools'||el.matches('[class~="group/site-card"]'))fixSurface(el);
    if(kind==='codeblock')fixCode(el);
    intersection.observe(el);
  }
  function classify(el){
    if(el.matches(homeComposerBody))return'transparent';
    if(el.matches(composerTools))return'composer-tools';
    if(el.matches(pageSurface))return el.parentElement?.closest(pageSurface)?'page-layout':'page';
    if(el.matches('[class~="group/site-card"]'))return'card';
    if(el.matches(sidebarRail))return'rail';
    if(el.matches(sidebarLayer))return'transparent';
    if(el.matches(pageHeader))return'header';
    if(el.matches(resourceRow))return el.closest('[data-dream-glass="message"],[data-dream-glass="card"]')?'control':null;
    if(el.matches(chatgptMessage))return'message';
    if(el.matches(assistantMarkdown))return el.closest('[data-chatgpt-search-unit-key],[class~="group/agent-activity"],[data-local-conversation-final-assistant]')?null:'message';
    if(el.matches(settingsIcon+','+chatgptIcon))return'icon';
    if(el.matches(settingsControl+','+chatgptControl))return'control';
    if(el.matches(settingsPanel))return'settings';
    if(el.matches('[data-code-block]'))return'codeblock';
    if(el.matches('[class~="group/summary-panel"]'))return'resource';
    if(el.matches('pre'))return'code';
    if(el.matches('[class*="_ApplicationMenuTopBar_"]'))return'topbar';
    if(el.matches('aside.app-shell-left-panel,.app-shell-right-panel'))return'sidebar';
    if(el.matches('[class*="_ComposerLayoutRoot_"]'))return'composer';
    if(el.matches('.bg-user-message'))return'user';
    if(el.matches('[class~="group/agent-activity"],[data-local-conversation-final-assistant]'))return'message';
    if(el.matches('header'))return el.parentElement?.closest('header,[class~="group/summary-panel"]')?null:'header';
    if(el.matches('[role="dialog"],[role="menu"],[role="listbox"],[role="tooltip"],[data-radix-menu-content]'))return'popup';
    return'card';
  }
  function discover(scope){
    stats.discoveryPasses++;
    const candidates=[];if(scope.nodeType===1&&scope.matches(selectors+','+extraSurfaces))candidates.push(scope);
    if(scope.querySelectorAll)candidates.push(...scope.querySelectorAll(selectors+','+extraSurfaces));
    if(scope.nodeType===1&&(scope.matches('[data-testid="sites-grid"],[data-profile-scroll]')||scope.querySelector('[data-testid="sites-grid"],[data-profile-scroll]'))){for(let el=scope.parentElement;el;el=el.parentElement)if(el.matches(pageSurface))candidates.unshift(el);}
    for(const el of candidates){
      // A streamed Markdown root may arrive after its ChatGPT turn wrapper.
      if(el.matches(assistantMarkdown)){const unit=el.closest('[data-chatgpt-search-unit-key]');if(unit)tag(unit,'message');}
      const kind=classify(el);if(kind==='page-layout'){if(!layouts.has(el))layouts.set(el,ownAttr(el,'data-dream-glass-layout','true'));fixSurface(el,true);}else if(kind==='control')fixControl(el);else if(kind==='transparent')fixSurface(el,true);else if(kind==='icon')fixForeground(el);else if(kind)tag(el,kind);
    }
  }
  function colorInfo(value){
    if(value.startsWith('oklab(')){const a=value.match(/-?[\d.]+/g)?.map(Number);return{neutral:!!a&&Math.abs(a[1]||0)+Math.abs(a[2]||0)<.06,alpha:a?.[3]??1};}
    if(value.startsWith('color(srgb ')){const a=value.match(/-?[\d.]+/g)?.map(Number);return{neutral:!!a&&Math.max(...a.slice(0,3))-Math.min(...a.slice(0,3))<.23,alpha:a?.[3]??1};}
    const a=value.match(/[\d.]+/g)?.map(Number);return{neutral:!!a&&Math.max(...a.slice(0,3))-Math.min(...a.slice(0,3))<58,alpha:a?.[3]??1};
  }
  function repair(scope){
    if(!scope.isConnected||(!scope.closest?.('[data-dream-glass]')&&!scope.querySelector?.('[data-dream-glass]')))return;
    stats.textPasses++;
    const parents=new Set();
    const walker=document.createTreeWalker(scope,NodeFilter.SHOW_TEXT,{acceptNode(node){const p=node.parentElement;return p&&!p.closest(skipped)&&node.nodeValue.trim()&&p.closest('[data-dream-glass]')?NodeFilter.FILTER_ACCEPT:NodeFilter.FILTER_REJECT;}});
    let node;while((node=walker.nextNode()))if(!texts.has(node.parentElement))parents.add(node.parentElement);
    const writes=[];
    for(const el of parents){
      const c=getComputedStyle(el);if(c.visibility==='hidden')continue;
      const info=colorInfo(c.color),link=!info.neutral&&(el.closest('a,[role="link"]')||String(el.className).includes('_Label_'));
      if(!info.neutral&&!link)continue;
      const button=el.closest('button');if(button){const bg=getComputedStyle(button).backgroundColor;if(bg.startsWith('rgb('))continue;}
      writes.push({el,type:link?'link':info.alpha<.95?'muted':'primary'});
    }
    for(const{el,type}of writes){
      texts.set(el,{attr:el.getAttribute('data-dream-glass-text'),color:el.style.getPropertyValue('color'),priority:el.style.getPropertyPriority('color')});
      el.dataset.dreamGlassText=type;el.style.setProperty('color',`var(--dg-${type==='primary'?'ink':type})`,'important');stats.repairedText++;
    }
  }
  function queue(scope){if(disposed||!scope||inWallpaper(scope))return;pendingRoots.add(scope);if(!workTimer)workTimer=setTimeout(()=>{workTimer=null;idleHandle=requestIdleCallback(flush,{timeout:300});},workDelay);}
  function flush(){
    idleHandle=null;if(disposed||document.hidden)return;
    const start=performance.now(),roots=[...pendingRoots];pendingRoots.clear();
    const outer=roots.filter(el=>el.isConnected&&!roots.some(other=>other!==el&&other.contains(el)));
    for(const el of outer){discover(el);repair(el);stats.processedRoots++;if(performance.now()-start>10){for(const rest of outer.slice(outer.indexOf(el)+1))pendingRoots.add(rest);break;}}
    const elapsed=performance.now()-start;stats.workTotalMs+=elapsed;stats.maxWorkMs=Math.max(stats.maxWorkMs,elapsed);
    if(pendingRoots.size&&!workTimer)workTimer=setTimeout(()=>{workTimer=null;idleHandle=requestIdleCallback(flush,{timeout:300});},workDelay);
  }
  function cleanup(scope){
    if(scope.isConnected)return;const nodes=[scope,...scope.querySelectorAll('[data-dream-glass],[data-dream-glass-text],[data-dg-surface],code')];
    for(const el of nodes){const surface=surfaceOverrides.get(el);if(surface){restoreSurface(el,surface);surfaceOverrides.delete(el);}const code=codeOverrides.get(el);if(code){restoreCode(el,code);codeOverrides.delete(el);}const text=texts.get(el);if(text){restoreText(el,text);texts.delete(el);}const m=materials.get(el);if(m){intersection.unobserve(el);visible.delete(el);restoreAttr(el,'data-dream-glass',m.material);restoreAttr(el,'data-dream-glass-scheme',m.scheme);restoreAttr(el,'data-dg-inview',m.inview);materials.delete(el);}}
  }
  const intersection=new IntersectionObserver(entries=>{
    for(const entry of entries){const el=entry.target;if(entry.isIntersecting){visible.add(el);if(el.dataset.dgInview!=='true')el.dataset.dgInview='true';queue(el);}else{visible.delete(el);if(el.hasAttribute('data-dg-inview'))el.removeAttribute('data-dg-inview');}}
  },{rootMargin:'80px'});
  function luma(r,g,b){return[r,g,b].map(x=>{x/=255;return x<=.04045?x/12.92:((x+.055)/1.055)**2.4;}).reduce((sum,x,i)=>sum+x*[.2126,.7152,.0722][i],0);}
  function choose(v,old){return old==='light'?(v<.23?'dark':'light'):old==='dark'?(v>.48?'light':'dark'):(v>.35?'light':'dark');}
  function adapt(force=false){
    if(disposed||document.hidden&&!force)return;
    const start=performance.now();
    try{
      const media=window.__CODEX_STATIC_WALLPAPER__?.image||document.querySelector('#codex-wallpaper-skin-host canvas.cws-media,#codex-wallpaper-skin-host video,#codex-wallpaper-skin-host img');
      if(!media)throw Error('Wallpaper unavailable');ctx.clearRect(0,0,32,20);ctx.drawImage(media,0,0,32,20);const p=ctx.getImageData(0,0,32,20).data;
      let sum=0,count=0;for(let y=2;y<18;y++)for(let x=6;x<31;x++){const i=(y*32+x)*4;if(p[i+3]>16){sum+=luma(p[i],p[i+1],p[i+2]);count++;}}
      if(!count)throw Error('Wallpaper frame is empty');const mean=sum/count;stats.mean=mean;smoothed=force||smoothed===null?mean:smoothed*.4+mean*.6;
      const next=choose(smoothed,force?null:currentScheme);if(next===candidate)candidateCount++;else{candidate=next;candidateCount=1;}
      if(currentScheme===null||force||next!==currentScheme&&candidateCount>=2){
        if(next!==currentScheme){currentScheme=next;root.dataset.dreamGlassScheme=next;for(const[el,m]of materials)if(m.kind!=='codeblock'&&m.kind!=='code'&&el.dataset.dreamGlassScheme!==next)el.dataset.dreamGlassScheme=next;stats.updates++;}
      }
      stats.samples++;stats.lastSampleAt=Date.now();stats.lastError=null;
    }catch(e){stats.lastError=e.name+': '+e.message;}
    stats.sampleTotalMs+=performance.now()-start;
  }
  const observer=new MutationObserver(records=>{
    for(const record of records){for(const node of record.addedNodes)if(node.nodeType===1)queue(node);else if(node.nodeType===3&&record.target.nodeType===1)queue(record.target);for(const node of record.removedNodes)if(node.nodeType===1)cleanup(node);}
  });
  function visibility(){if(document.hidden){if(workTimer){clearTimeout(workTimer);workTimer=null;}if(idleHandle){cancelIdleCallback(idleHandle);idleHandle=null;}}else{adapt();if(pendingRoots.size)queue(document.body);}}
  root.dataset.codexDreamGlass='true';adapt(true);
  if(!currentScheme){currentScheme=getComputedStyle(root).colorScheme.includes('dark')?'dark':'light';root.dataset.dreamGlassScheme=currentScheme;}
  document.querySelectorAll(structural).forEach(el=>layouts.set(el,ownAttr(el,'data-dream-glass-layout','true')));
  discover(document);for(const el of document.querySelectorAll('aside.app-shell-left-panel,[class*="_ApplicationMenuTopBar_"],[class*="_ComposerLayoutRoot_"]'))queue(el);
  observer.observe(document.body,{childList:true,subtree:true});document.addEventListener('visibilitychange',visibility);sampleTimer=setInterval(()=>{if(!window.__CODEX_STATIC_WALLPAPER__?.image)adapt();},sampleInterval);
  setDensity(64);setBlur(4);
  const api={version:'3.6.14',get density(){return stats.density;},get blur(){return stats.blur;},setDensity,setBlur,scope:'light-frost-native-materials',adapt,selfTest(){return{darkWallpaper:choose(.02,null)==='dark',lightWallpaper:choose(.92,null)==='light',lightHysteresis:choose(.3,'light')==='light',darkHysteresis:choose(.4,'dark')==='dark'};},diagnostics(){return{...stats,samplingIntervalMs:sampleInterval,samplingPaused:document.hidden,scheme:currentScheme,visibleSurfaces:visible.size,pendingRoots:pendingRoots.size,surfaceCounts:[...materials.values()].reduce((a,m)=>{a[m.kind]=(a[m.kind]||0)+1;return a;},{})};},dispose(){
    disposed=true;observer.disconnect();intersection.disconnect();clearInterval(sampleTimer);clearTimeout(workTimer);if(idleHandle)cancelIdleCallback(idleHandle);document.removeEventListener('visibilitychange',visibility);
    for(const[el,old]of texts)restoreText(el,old);for(const[el,old]of codeOverrides)restoreCode(el,old);for(const[el,old]of surfaceOverrides)restoreSurface(el,old);for(const[el,m]of materials){restoreAttr(el,'data-dream-glass',m.material);restoreAttr(el,'data-dream-glass-scheme',m.scheme);restoreAttr(el,'data-dg-inview',m.inview);}for(const[el,old]of layouts)restoreAttr(el,'data-dream-glass-layout',old);
    style.remove();root.removeAttribute('data-codex-dream-glass');root.removeAttribute('data-dream-glass-scheme');restoreAttr(root,'data-dg-density',densityBefore.attr);if(densityBefore.value)root.style.setProperty('--dg-density-shift',densityBefore.value,densityBefore.priority);else root.style.removeProperty('--dg-density-shift');restoreAttr(root,'data-dg-blur',blurBefore.attr);if(blurBefore.value)root.style.setProperty('--dg-blur',blurBefore.value,blurBefore.priority);else root.style.removeProperty('--dg-blur');pendingRoots.clear();delete window[key];
  }};
  window[key]=api;return{applied:true,...api.diagnostics()};
})(__GLASS_CSS_JSON__)
