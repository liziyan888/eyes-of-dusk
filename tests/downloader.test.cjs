const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {loadPack,validateManifest,Tuner}=require('../web/downloader.js');
const baseURL='https://game.example/eyes/';
const sha=b=>createHash('sha256').update(b).digest('hex');
function fixture(count=5){
 const data=Array.from({length:count},(_,i)=>Buffer.alloc(4096+i,i+1));let offset=0;
 const parts=data.map(buffer=>{const hash=sha(buffer),part={file:'game-data/part-'+hash+'.bin',offset,bytes:buffer.length,sha256:hash};offset+=buffer.length;return part;});
 return {data,manifest:{pack_bytes:offset,pack_sha256:sha(Buffer.concat(data)),parts}};
}
class Cache{
 constructor(){this.items=new Map();}
 async match(key){return this.items.get(String(key))?.clone();}
 async put(key,response){this.items.set(String(key),new Response(await response.arrayBuffer(),{headers:response.headers}));}
 async delete(key){return this.items.delete(String(key));}
}
function storage(cache){return {open:async()=>cache};}
function network(f,calls,overrides={}){
 return async(url,options)=>{
  const index=f.manifest.parts.findIndex(p=>new URL(p.file,baseURL).href===url);calls.push(index);
  assert.notEqual(index,-1,'Only current resource URLs may be requested');
  if(overrides[index])return overrides[index](url,options);
  return new Response(f.data[index]);
 };
}
const settings={baseURL,sleep:async()=>{},concurrency:3};
test('manifest rejects missing, reordered and unsafe resource descriptors',()=>{
 const f=fixture();validateManifest(f.manifest);
 assert.throws(()=>validateManifest({...f.manifest,pack_bytes:2}));
 assert.throws(()=>validateManifest({...f.manifest,parts:[...f.manifest.parts].reverse()}));
 assert.throws(()=>validateManifest({...f.manifest,parts:[{...f.manifest.parts[0],file:'https://other.example/key'}]}));
});
test('out-of-order network completion assembles the exact pack and saves verified parts',async()=>{
 const f=fixture(),cache=new Cache(),calls=[],progress=[];
 const result=await loadPack(f.manifest,{...settings,caches:storage(cache),onProgress:v=>progress.push(v),fetch:network(f,calls,{0:async()=>{await new Promise(r=>setTimeout(r,15));return new Response(f.data[0]);}})});
 assert.equal(sha(result.pack),f.manifest.pack_sha256);assert.equal(calls.length,f.data.length);
 assert.equal(result.stats.networkBytes,f.manifest.pack_bytes);assert.equal(cache.items.size,f.data.length);
 assert.equal(progress.at(-1).loaded,f.manifest.pack_bytes);
});
test('refresh resumes completed fragments after a failed load',async()=>{
 const f=fixture(),cache=new Cache(),calls=[];
 await assert.rejects(loadPack(f.manifest,{...settings,concurrency:1,caches:storage(cache),fetch:network(f,[],{1:async()=>new Response(null,{status:404})})}));
 assert.ok(await cache.match(new URL(f.manifest.parts[0].file,baseURL).href));
 const result=await loadPack(f.manifest,{...settings,caches:storage(cache),fetch:network(f,calls)});
 assert.equal(sha(result.pack),f.manifest.pack_sha256);assert.ok(!calls.includes(0));assert.equal(result.stats.cachedBytes,f.data[0].length);
});
test('a complete cached pack requires zero network requests',async()=>{
 const f=fixture(),cache=new Cache();
 await loadPack(f.manifest,{...settings,caches:storage(cache),fetch:network(f,[])});
 const result=await loadPack(f.manifest,{...settings,caches:storage(cache),fetch:async()=>{throw new Error('Unexpected network request');}});
 assert.equal(sha(result.pack),f.manifest.pack_sha256);assert.equal(result.stats.networkBytes,0);assert.equal(result.stats.cachedBytes,f.manifest.pack_bytes);
});
test('a corrupted cache fragment is discarded and fetched again',async()=>{
 const f=fixture(),cache=new Cache(),calls=[];
 await loadPack(f.manifest,{...settings,caches:storage(cache),fetch:network(f,[])});
 await cache.put(new URL(f.manifest.parts[2].file,baseURL).href,new Response(Buffer.alloc(f.data[2].length,99)));
 const result=await loadPack(f.manifest,{...settings,caches:storage(cache),fetch:network(f,calls)});
 assert.deepEqual(calls,[2]);assert.equal(sha(result.pack),f.manifest.pack_sha256);
});
test('legacy large cached fragments are reused only for matching verified slices',async()=>{
 const f=fixture(),cache=new Cache(),calls=[],oldData=Buffer.concat(f.data.map((b,i)=>i===1?Buffer.alloc(b.length,50):b));
 const hash=sha(oldData),file='game-data/part-'+hash+'.bin';
 await cache.put(new URL(file,baseURL).href,new Response(oldData));
 const manifest={...f.manifest,legacy_pack_sha256:'0'.repeat(64),legacy_parts:[{file,sha256:hash,bytes:oldData.length,offset:0}]};
 const result=await loadPack(manifest,{...settings,caches:storage(cache),fetch:network(f,calls)});
 assert.deepEqual(calls,[1]);assert.equal(sha(result.pack),f.manifest.pack_sha256);
});
test('a hash mismatch retries and never stores the damaged response',async()=>{
 const f=fixture(1),cache=new Cache(),calls=[];let request=0;
 const result=await loadPack(f.manifest,{...settings,caches:storage(cache),fetch:network(f,calls,{0:async()=>new Response(request++===0?Buffer.alloc(f.data[0].length,9):f.data[0])})});
 assert.equal(calls.length,2);assert.equal(result.stats.retries,1);assert.equal(sha(result.pack),f.manifest.pack_sha256);
 assert.equal(sha(Buffer.from(await (await cache.match(new URL(f.manifest.parts[0].file,baseURL).href)).arrayBuffer())),f.manifest.parts[0].sha256);
});
test('blocked browser storage and cache quota exhaustion do not prevent playing',async()=>{
 const f=fixture();
 for(const caches of [null,{open:async()=>{throw new Error('Private mode');}},{open:async()=>({match:async()=>undefined,put:async()=>{throw new Error('Quota exceeded');}})}]){
  const result=await loadPack(f.manifest,{...settings,caches,fetch:network(f,[])});assert.equal(sha(result.pack),f.manifest.pack_sha256);
 }
});
test('a missing immutable fragment fails immediately for the version-recovery path',async()=>{
 const f=fixture(1),calls=[];
 await assert.rejects(loadPack(f.manifest,{...settings,caches:null,fetch:network(f,calls,{0:async()=>new Response(null,{status:404})})}));
 assert.equal(calls.length,1);
});
test('a stalled request times out and stops after bounded retries',async()=>{
 const f=fixture(1),calls=[];
 await assert.rejects(loadPack(f.manifest,{...settings,caches:null,idleTimeoutMs:8,fetch:network(f,calls,{0:async(url,{signal})=>new Promise((resolve,reject)=>signal.addEventListener('abort',()=>reject(signal.reason),{once:true}))})}));
 assert.equal(calls.length,5);
});
test('cancelling a transfer aborts active requests',async()=>{
 const f=fixture(1),controller=new AbortController();
 const result=loadPack(f.manifest,{...settings,caches:null,signal:controller.signal,fetch:async(url,{signal})=>new Promise((resolve,reject)=>{signal.addEventListener('abort',()=>reject(signal.reason),{once:true});setTimeout(()=>controller.abort(new Error('User pause')),10);})});
 await assert.rejects(result,/User pause/);
});
test('adaptive concurrency compares 3/6/8 and chooses fewer connections for equivalent speed',()=>{
 const tuner=new Tuner(8);assert.equal(tuner.sample(0,0),3);
 assert.equal(tuner.sample(6000,3e6),6);assert.equal(tuner.sample(12000,9e6),8);
 assert.equal(tuner.sample(18000,15.3e6),6);assert.equal(tuner.settled,true);
 tuner.backoff();assert.equal(tuner.limit,3);
 assert.equal(new Tuner(3).maximum,3);
});
