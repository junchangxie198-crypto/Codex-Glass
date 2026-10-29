// Missing setting preserves wallpapers for users of older versions.
export async function reconcileWallpaper({state,evaluate,wallpaper,wallpaperId}) {
  const active=await evaluate('window.__CODEX_STATIC_WALLPAPER__?.id || null');
  if(state.wallpaperEnabled===false){
    if(active)await evaluate('window.__CODEX_STATIC_WALLPAPER__?.dispose()');
    return {enabled:false,active:false};
  }
  if(!wallpaper || !wallpaperId)return {enabled:true,active:false};
  if(active!==wallpaperId){const result=await evaluate(wallpaper);if(!result?.ready||result.id!==wallpaperId)throw Error('Wallpaper application failed');}
  return {enabled:true,active:true};
}
