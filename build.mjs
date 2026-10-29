import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
const [template, baseCss, clearCss] = await Promise.all(['clear-template.js','adaptive.css','clear-glass.css'].map(name=>fs.readFile(new URL(name,import.meta.url),'utf8')));
const css=baseCss+'\n'+clearCss;
if (!template.includes('__GLASS_CSS_JSON__') || !css.includes('--dg-ink')) throw Error('Invalid glass source');
await fs.writeFile(new URL('apply.js',import.meta.url),template.replace('__GLASS_CSS_JSON__',()=>JSON.stringify(css)),'utf8');
const wallpaperPath=new URL('assets/user-wallpaper.jpg',import.meta.url);
try {
  const bytes=await fs.readFile(wallpaperPath);
  const mime=bytes.subarray(0,3).equals(Buffer.from([255,216,255]))?'image/jpeg':bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))?'image/png':null;
  if(!mime)throw Error('Wallpaper must be JPEG or PNG');
  const source=await fs.readFile(new URL('wallpaper-template.js',import.meta.url),'utf8');
  const config={id:createHash('sha256').update(bytes).update(source).digest('hex'),source:`data:${mime};base64,`+bytes.toString('base64')};
  await fs.writeFile(new URL('wallpaper.js',import.meta.url),source.replace('__WALLPAPER_CONFIG_JSON__',()=>JSON.stringify(config)),'utf8');
}catch(error){if(error.code!=='ENOENT')throw error;}
