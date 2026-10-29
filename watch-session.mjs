// Called only after the PowerShell supervisor verifies Store identity and port ownership.
import fs from 'node:fs/promises';
import {watch} from 'node:fs';
import path from 'node:path';
import {setTimeout as delay} from 'node:timers/promises';
import {reconcile} from './watch-state.mjs';
import {reconcileWallpaper} from './wallpaper-state.mjs';
import {loadWallpaperPayload} from './wallpaper-payload.mjs';
const [portArg,browserId,statePath,statusPath]=process.argv.slice(2);
const port=Number(portArg);
if(!Number.isInteger(port)||port<1024||port>65535||!/^[A-Za-z0-9._-]{1,200}$/.test(browserId??''))throw Error('Invalid identity');
const base=`http://127.0.0.1:${port}`;
const apply=await fs.readFile(new URL('apply.js',import.meta.url),'utf8');
const restore=await fs.readFile(new URL('restore.js',import.meta.url),'utf8');
let wallpaper=null,wallpaperId=null,loadedRevision=Symbol('initial');
const versionExpression=JSON.stringify(apply.match(/version:'([^']+)'/)?.[1]??'3.1.0');
let ws,nextId=0,lastStatus='';
let changed=false,wake;
const stateWatcher=watch(path.dirname(statePath),(_event,name)=>{if(name?.toString()!==path.basename(statePath))return;changed=true;wake?.();});
stateWatcher.on('error',()=>{changed=true;wake?.();});
function waitForChange(){if(changed){changed=false;return Promise.resolve();}return new Promise(resolve=>{let timer;const done=()=>{clearTimeout(timer);wake=undefined;changed=false;resolve();};wake=done;timer=setTimeout(done,1500);});}
const pending=new Map();
async function json(route){const r=await fetch(base+route,{signal:AbortSignal.timeout(3000)});if(!r.ok)throw Error(`HTTP ${r.status}`);return r.json();}
function call(method,params={}){return new Promise((resolve,reject)=>{const id=++nextId;const timer=setTimeout(()=>{pending.delete(id);reject(Error('Renderer timeout'));},8000);pending.set(id,{resolve,reject,timer});ws.send(JSON.stringify({id,method,params}));});}
async function evaluate(expression){const r=await call('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(r.exceptionDetails.exception?.description??r.exceptionDetails.text);return r.result?.value;}
async function report(value){const status={...value,updatedAt:new Date().toISOString(),pid:process.pid};const key=JSON.stringify(value);if(key!==lastStatus){await fs.writeFile(statusPath,JSON.stringify(status,null,2));lastStatus=key;}}
try{
  while(true){
    const version=await json('/json/version');
    if(version.webSocketDebuggerUrl!==`ws://127.0.0.1:${port}/devtools/browser/${browserId}`)throw Error('Session identity changed');
    const targets=(await json('/json/list')).filter(t=>t.type==='page'&&t.url==='app://-/index.html');
    if(targets.length!==1){await report({status:'waiting',reason:'Waiting for one main page'});await delay(3000);continue;}
    const target=targets[0];
    if(!/^[A-Za-z0-9._-]+$/.test(target.id)||target.webSocketDebuggerUrl!==`ws://127.0.0.1:${port}/devtools/page/${target.id}`)throw Error('Rejected target');
    ws=new WebSocket(target.webSocketDebuggerUrl);
    await Promise.race([new Promise((resolve,reject)=>{ws.addEventListener('open',resolve,{once:true});ws.addEventListener('error',reject,{once:true});}),delay(5000).then(()=>{throw Error('Connect timeout');})]);
    ws.addEventListener('error',()=>{});
    ws.addEventListener('message',e=>{const m=JSON.parse(e.data),p=pending.get(m.id);if(!p)return;pending.delete(m.id);clearTimeout(p.timer);m.error?p.reject(Error(m.error.message)):p.resolve(m.result);});
    ws.addEventListener('close',()=>{for(const p of pending.values()){clearTimeout(p.timer);p.reject(Error('Page closed'));}pending.clear();});
    try{
      while(ws.readyState===WebSocket.OPEN){
        // Browser id is pinned for the whole worker; replacement requires supervisor validation.
        const current=await json('/json/version');
        if(current.webSocketDebuggerUrl!==version.webSocketDebuggerUrl)throw Error('Session identity changed');
        let state;
        try{state=JSON.parse(await fs.readFile(statePath,'utf8'));if(typeof state.enabled!=='boolean')throw Error('Invalid state');}
        catch(error){await report({status:'error',reason:'Cannot read saved switch: '+error.message});await delay(3000);continue;}
        try{
          const revision=typeof state.wallpaperRevision==='string'?state.wallpaperRevision:null;
          if(loadedRevision!==revision){
            ({wallpaper,wallpaperId}=await loadWallpaperPayload(new URL('assets/user-wallpaper.jpg',import.meta.url),new URL('wallpaper-template.js',import.meta.url)));
            loadedRevision=revision;
          }
          const wallpaperStatus=await reconcileWallpaper({state,evaluate,wallpaper,wallpaperId});
          const snapshot=await evaluate(`(() => ({url:location.href,ready:!!document.querySelector('aside.app-shell-left-panel,.ProseMirror[contenteditable="true"]'),active:!!window.__CODEX_DREAM_GLASS__&&!!document.getElementById('codex-dream-glass-style'),version:window.__CODEX_DREAM_GLASS__?.version,density:window.__CODEX_DREAM_GLASS__?.density,blur:window.__CODEX_DREAM_GLASS__?.blur,expectedVersion:${versionExpression}}))()`);
          const result=await reconcile({state,snapshot,evaluate,apply,restore});
          await report({...result,wallpaper:wallpaperStatus,wallpaperRevision:wallpaperStatus.active?revision:null,targetId:target.id});
        }catch(error){await report({status:'waiting',reason:error.message.slice(0,500)});}
        await waitForChange();
      }
    }finally{ws.close();}
    await delay(1500);
  }
}catch(error){await report({status:'disconnected',reason:error.message.slice(0,500)});process.exitCode=1;}
finally{stateWatcher.close();ws?.close();}
