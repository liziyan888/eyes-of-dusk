/* Immutable, verified resource fragments. No image, audio or video transcoding. */
(function(root,factory){
 "use strict";
 const api=factory();
 if(typeof module==="object"&&module.exports)module.exports=api;
 else root.EyesDownload=api;
})(typeof globalThis!=="undefined"?globalThis:this,function(){
 "use strict";
 const CACHE_NAME="eyes-game-data-v1"; // Keep completed downloads from the original release.
 const MiB=1048576;
 const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
 const hex=buffer=>Array.from(new Uint8Array(buffer),b=>b.toString(16).padStart(2,"0")).join("");
 function validateManifest(manifest){
  if(!Number.isSafeInteger(manifest.pack_bytes)||manifest.pack_bytes<=0||manifest.pack_bytes>1073741824||!Array.isArray(manifest.parts)||!manifest.parts.length)throw new Error("游戏素材清单不完整");
  let offset=0;
  for(const part of manifest.parts){
   if(!/^game-data\/part-[a-f0-9]{64}\.bin$/.test(part.file)||!Number.isSafeInteger(part.bytes)||part.bytes<=0||part.bytes>64*MiB||part.offset!==offset||!/^\w{64}$/.test(part.sha256)||!part.file.includes(part.sha256))throw new Error("游戏素材清单校验失败");
   offset+=part.bytes;
  }
  if(offset!==manifest.pack_bytes)throw new Error("游戏素材长度不符");
 }
 class Tuner{
  constructor(maximum=8){
   this.maximum=Math.max(1,Math.min(8,maximum));
   this.levels=[3,6,8].map(n=>Math.min(n,this.maximum)).filter((n,i,a)=>!i||n!==a[i-1]);
   this.level=0;this.limit=this.levels[0];this.samples=[];this.started=null;this.bytes=0;this.settled=false;
  }
  sample(time,bytes){
   if(this.started===null){this.started=time;this.bytes=bytes;return this.limit;}
   const elapsed=time-this.started,transferred=bytes-this.bytes;
   if(this.settled||elapsed<6000||transferred<256*1024)return this.limit;
   this.samples.push({connections:this.limit,bytes_per_second:transferred/(elapsed/1000)});
   this.started=time;this.bytes=bytes;
   if(++this.level<this.levels.length)this.limit=this.levels[this.level];
   else{
    // Within 12% of the best measured throughput, prefer fewer connections.
    const best=Math.max(...this.samples.map(s=>s.bytes_per_second));
    this.limit=this.samples.find(s=>s.bytes_per_second>=best*.88).connections;
    this.settled=true;
   }
   return this.limit;
  }
  backoff(){this.limit=Math.max(1,Math.floor(this.limit/2));this.maximum=this.limit;this.settled=true;}
 }
 async function loadPack(manifest,options={}){
  validateManifest(manifest);
  const fetcher=options.fetch||globalThis.fetch.bind(globalThis);
  const digest=options.digest||(async buffer=>hex(await crypto.subtle.digest("SHA-256",buffer)));
  const clock=options.now||(()=>performance.now());
  const wait=options.sleep||pause;
  const idleTimeout=options.idleTimeoutMs||30000;
  const report=options.onProgress||(()=>{});
  const base=options.baseURL||globalThis.location.href;
  const controller=new AbortController();
  const signal=controller.signal;
  if(options.signal){
   if(options.signal.aborted)controller.abort(options.signal.reason);
   else options.signal.addEventListener("abort",()=>controller.abort(options.signal.reason),{once:true});
  }
  function cancelled(){if(signal.aborted)throw signal.reason||new Error("已暂停加载");}
  const pack=new Uint8Array(manifest.pack_bytes),loaded=manifest.parts.map(()=>0),done=new Set();
  let networkBytes=0,cachedBytes=0,retries=0,lastReport=-Infinity,cache=null,cacheWritable=true;
  const started=clock(),tuner=new Tuner(options.maxConcurrency||8);
  let limit=options.concurrency||tuner.limit,active=0;
  let speedTime=started,speedBytes=0,speed=0;
  function progress(force=false){
   const time=clock();
   if(!force&&time-lastReport<125)return; // Streaming reads must not redraw the DOM thousands of times.
   const seconds=(time-speedTime)/1000;
   if(seconds>=1){speed=(networkBytes-speedBytes)/seconds;speedTime=time;speedBytes=networkBytes;}
   lastReport=time;
   report({loaded:loaded.reduce((a,b)=>a+b,0),total:manifest.pack_bytes,cachedBytes,networkBytes,speed,connections:limit,retries,completed:done.size,parts:manifest.parts.length});
  }
  try{
   const storage=options.caches===undefined?globalThis.caches:options.caches;
   if(storage)cache=await storage.open(CACHE_NAME);
  }catch(error){/* Private mode and storage quotas must never prevent playing. */}
  function accept(buffer,part,index,fromCache){
   pack.set(buffer,part.offset);loaded[index]=part.bytes;done.add(index);
   if(fromCache)cachedBytes+=part.bytes;
   progress();
  }
  const writes=new Set();
  async function persist(buffer,part){
   if(!cache||!cacheWritable)return;
   // Bound pending copies; a slow disk cannot build an unbounded memory queue.
   while(writes.size>=2)await Promise.race(writes);
   if(!cacheWritable)return;
   const task=cache.put(new URL(part.file,base).href,new Response(buffer,{headers:{"Content-Type":"application/octet-stream","X-Eyes-SHA256":part.sha256}})).catch(()=>{cacheWritable=false;}).finally(()=>writes.delete(task));
   writes.add(task);
  }
  if(cache){
   // A cache-first pass ensures refreshing never re-downloads verified fragments.
   for(let index=0;index<manifest.parts.length;index++){
    cancelled();const part=manifest.parts[index],url=new URL(part.file,base).href;
    try{
     const stored=await cache.match(url);
     if(!stored)continue;
     const buffer=new Uint8Array(await stored.arrayBuffer());
     if(buffer.length===part.bytes&&await digest(buffer)===part.sha256)accept(buffer,part,index,true);
     else await cache.delete(url);
    }catch(error){/* Treat an unreadable optional cache entry as a miss. */}
   }
   // Read existing 32 MiB cached parts locally. Never request removed legacy URLs.
   if(Array.isArray(manifest.legacy_parts)){
    for(const old of manifest.legacy_parts){
     cancelled();
     const indexes=manifest.parts.map((p,i)=>i).filter(i=>!done.has(i)&&manifest.parts[i].offset>=old.offset&&manifest.parts[i].offset+manifest.parts[i].bytes<=old.offset+old.bytes);
     if(!indexes.length||!/^game-data\/part-[a-f0-9]{64}\.bin$/.test(old.file))continue;
     try{
      const stored=await cache.match(new URL(old.file,base).href);
      if(!stored)continue;
      const buffer=new Uint8Array(await stored.arrayBuffer());
      if(buffer.length!==old.bytes||await digest(buffer)!==old.sha256)continue;
      for(const index of indexes){
       const part=manifest.parts[index],slice=buffer.subarray(part.offset-old.offset,part.offset-old.offset+part.bytes);
       if(await digest(slice)===part.sha256)accept(slice,part,index,true);
      }
     }catch(error){/* The old cache remains optional and is never bulk-deleted. */}
    }
   }
  }
  progress(true);
  const pending=manifest.parts.map((p,i)=>i).filter(i=>!done.has(i));
  let next=0,fatal=null,tick=null;
  async function download(part,index){
   for(let attempt=0;attempt<5;attempt++){
    cancelled();let reader=null,timeout=null;
    const requestController=new AbortController();
    const abort=()=>requestController.abort(signal.reason);
    signal.addEventListener("abort",abort,{once:true});
    function touch(){clearTimeout(timeout);timeout=setTimeout(()=>requestController.abort(new Error("连接暂时无响应，正在重试")),idleTimeout);}
    try{
     loaded[index]=0;progress();touch();
     const response=await fetcher(new URL(part.file,base).href,{cache:attempt?"reload":"default",signal:requestController.signal});
     if(!response.ok){const error=new Error("素材暂时无法下载（"+response.status+"）");error.status=response.status;throw error;}
     const buffer=new Uint8Array(part.bytes);let offset=0;
     if(response.body){
      reader=response.body.getReader();
      while(true){
       const result=await reader.read();if(result.done)break;
       touch();if(offset+result.value.length>buffer.length)throw new Error("素材长度不符");
       buffer.set(result.value,offset);offset+=result.value.length;networkBytes+=result.value.length;loaded[index]=offset;progress();
      }
     }else{
      const value=new Uint8Array(await response.arrayBuffer());
      if(value.length!==buffer.length)throw new Error("素材长度不符");
      buffer.set(value);offset=value.length;networkBytes+=offset;
     }
     clearTimeout(timeout);
     if(offset!==part.bytes)throw new Error("素材尚未下载完整");
     if(await digest(buffer)!==part.sha256)throw new Error("素材校验失败，正在重新获取");
     cancelled();accept(buffer,part,index,false);await persist(buffer,part);return;
    }catch(error){
     if(reader)try{await reader.cancel();}catch(ignored){}
     requestController.abort();cancelled();
     loaded[index]=0;progress(true);
     // A missing immutable fragment indicates a new deployment; do not repeat it five times.
     if(error.status===404||attempt===4)throw error;
     retries++;
     if(error.status===429||error.name==="AbortError"||attempt>=1){tuner.backoff();limit=Math.min(limit,tuner.limit);}
     await wait(Math.min(8000,500*2**attempt));
    }finally{
     clearTimeout(timeout);signal.removeEventListener("abort",abort);
    }
   }
  }
  try{
   await new Promise((resolve,reject)=>{
    function pump(){
     if(fatal)return;
     if(signal.aborted){fatal=signal.reason||new Error("已暂停加载");reject(fatal);return;}
     if(next===pending.length&&active===0){resolve();return;}
     while(active<limit&&next<pending.length){
      const index=pending[next++];active++;
      download(manifest.parts[index],index).then(()=>{active--;pump();}).catch(error=>{if(!fatal){fatal=error;controller.abort(error);reject(error);}});
     }
    }
    tick=setInterval(()=>{if(!options.concurrency)limit=tuner.sample(clock(),networkBytes);progress();pump();},500);
    pump();
   });
   await Promise.all(writes);progress(true);
   return {pack,stats:{networkBytes,cachedBytes,retries,seconds:(clock()-started)/1000,connections:limit,samples:tuner.samples}};
  }finally{clearInterval(tick);}
 }
 return {loadPack,validateManifest,Tuner,CACHE_NAME};
});
