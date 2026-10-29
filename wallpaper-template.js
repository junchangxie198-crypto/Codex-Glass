(async ({source,id}) => {
  if(location.href!=='app://-/index.html')throw Error('Invalid wallpaper target');
  if(window.__CODEX_STATIC_WALLPAPER__?.id===id)return {id,ready:true};
  const image=new Image();image.src=source;await image.decode();
  const old=window.__CODEX_STATIC_WALLPAPER__;
  const fade=!!old?.image&&!matchMedia('(prefers-reduced-motion: reduce)').matches;
  const previousImage=fade?old.image.cloneNode(false):null;
  window.__CODEX_STATIC_WALLPAPER__?.dispose();
  const root=document.documentElement,previous=root.getAttribute('data-codex-static-wallpaper');
  const style=document.createElement('style');style.id='codex-static-wallpaper-style';
  image.id='codex-static-wallpaper-image';image.className='codex-static-wallpaper-image';image.setAttribute('aria-hidden','true');
  style.textContent=`html[data-codex-static-wallpaper]{background:transparent!important;}
  html[data-codex-static-wallpaper] .codex-static-wallpaper-image{position:fixed!important;inset:0!important;width:100%!important;height:100%!important;object-fit:cover!important;object-position:center!important;z-index:-1!important;pointer-events:none!important;}
  html[data-codex-static-wallpaper] :is(body,#root,main[class*="_MainContentSurface_"],[data-app-shell-page-surface],[data-app-shell-frame],[class*="_Workspace_"],[class*="_PageSurfaceLayout_"],.thread-scroll-container){background-color:transparent!important;}
  html[data-codex-static-wallpaper] #codex-wallpaper-skin-host{visibility:hidden!important;}`;
  style.textContent+=`html[data-codex-static-wallpaper] [class*="_background_"][class*="_surface_"].pointer-events-none{background:transparent!important;}`;
  document.head.append(style);
  let fadeTimer=null;
  if(previousImage){previousImage.removeAttribute('id');previousImage.className='codex-static-wallpaper-image';document.body.prepend(previousImage);image.style.opacity='0';image.style.transition='opacity 180ms ease-out';previousImage.after(image);}
  else document.body.prepend(image);
  root.setAttribute('data-codex-static-wallpaper',id);
  window.__CODEX_STATIC_WALLPAPER__={id,image,dispose(){if(fadeTimer)clearTimeout(fadeTimer);previousImage?.remove();image.remove();style.remove();if(previous===null)root.removeAttribute('data-codex-static-wallpaper');else root.setAttribute('data-codex-static-wallpaper',previous);delete window.__CODEX_STATIC_WALLPAPER__;}};
  if(previousImage){requestAnimationFrame(()=>requestAnimationFrame(()=>{image.style.opacity='1';}));fadeTimer=setTimeout(()=>{previousImage.remove();image.style.removeProperty('opacity');image.style.removeProperty('transition');},250);}
  window.__CODEX_DREAM_GLASS__?.adapt(true);
  return {id,ready:true,width:image.naturalWidth,height:image.naturalHeight};
})(__WALLPAPER_CONFIG_JSON__)
