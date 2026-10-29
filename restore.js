(() => {
  window.__CODEX_DREAM_GLASS__?.dispose();
  return {restored:!document.getElementById('codex-dream-glass-style')&&!document.documentElement.hasAttribute('data-codex-dream-glass')};
})()
