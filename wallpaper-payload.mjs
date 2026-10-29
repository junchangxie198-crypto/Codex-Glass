import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
export async function loadWallpaperPayload(imagePath,templatePath){
  let bytes;
  try{bytes=await fs.readFile(imagePath)}catch(error){if(error.code==='ENOENT')return {wallpaper:null,wallpaperId:null};throw error}
  const mime=bytes.subarray(0,3).equals(Buffer.from([255,216,255]))?'image/jpeg':bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))?'image/png':null;
  if(!mime)throw Error('Wallpaper must be JPEG or PNG');
  const template=await fs.readFile(templatePath,'utf8');
  const config={id:createHash('sha256').update(bytes).update(template).digest('hex'),source:`data:${mime};base64,`+bytes.toString('base64')};
  return {wallpaper:template.replace('__WALLPAPER_CONFIG_JSON__',()=>JSON.stringify(config)),wallpaperId:config.id};
}
