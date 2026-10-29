import test from 'node:test';
import assert from 'node:assert/strict';
import {reconcileWallpaper} from './wallpaper-state.mjs';
function fixture(initial=null){let active=initial;const calls=[];return{calls,get active(){return active},evaluate:async code=>{calls.push(code);if(code.includes('?.id'))return active;if(code.includes('?.dispose')){active=null;return}if(code==='payload'){active='new-id';return{id:'new-id',ready:true}}throw Error('Unexpected evaluation')}}}
test('legacy preference restores a saved image',async()=>{const f=fixture();assert.deepEqual(await reconcileWallpaper({state:{},evaluate:f.evaluate,wallpaper:'payload',wallpaperId:'new-id'}),{enabled:true,active:true});assert.equal(f.active,'new-id')});
test('switch off removes only the wallpaper',async()=>{const f=fixture('old-id');assert.deepEqual(await reconcileWallpaper({state:{wallpaperEnabled:false},evaluate:f.evaluate,wallpaper:'payload',wallpaperId:'new-id'}),{enabled:false,active:false});assert.equal(f.active,null);assert.equal(f.calls.length,2)});
test('switch on restores saved image and stays idempotent',async()=>{const f=fixture();const args={state:{wallpaperEnabled:true},evaluate:f.evaluate,wallpaper:'payload',wallpaperId:'new-id'};await reconcileWallpaper(args);await reconcileWallpaper(args);assert.equal(f.calls.filter(c=>c==='payload').length,1)});
test('missing image does not remove other effects or fail',async()=>{const f=fixture();assert.deepEqual(await reconcileWallpaper({state:{wallpaperEnabled:true},evaluate:f.evaluate,wallpaper:null,wallpaperId:null}),{enabled:true,active:false})});
