import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {loadWallpaperPayload} from './wallpaper-payload.mjs';

test('wallpaper payload follows the selected file and rejects invalid formats',async()=>{
  const dir=await fs.mkdtemp(path.join(os.tmpdir(),'glass-wallpaper-test-'));
  try{
    const image=path.join(dir,'image'),template=path.join(dir,'template');
    await fs.writeFile(template,'use(__WALLPAPER_CONFIG_JSON__)');
    assert.deepEqual(await loadWallpaperPayload(image,template),{wallpaper:null,wallpaperId:null});
    await fs.writeFile(image,Buffer.from([255,216,255,0]));
    const first=await loadWallpaperPayload(image,template);assert.match(first.wallpaper,/data:image\/jpeg;base64,/);
    await fs.writeFile(image,Buffer.from([137,80,78,71,13,10,26,10,0]));
    const second=await loadWallpaperPayload(image,template);assert.match(second.wallpaper,/data:image\/png;base64,/);assert.notEqual(first.wallpaperId,second.wallpaperId);
    await fs.writeFile(image,'invalid');await assert.rejects(loadWallpaperPayload(image,template),/JPEG or PNG/);
  }finally{await fs.rm(dir,{recursive:true,force:true})}
});
