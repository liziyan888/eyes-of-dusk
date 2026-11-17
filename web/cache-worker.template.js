"use strict";
const DATA_CACHE="eyes-game-data-v1";
const ENGINE_CACHE="eyes-game-engine-v2";
const ENGINE_SHA256="__ENGINE_SHA256__";
self.addEventListener("install",event=>event.waitUntil(self.skipWaiting()));
self.addEventListener("activate",event=>event.waitUntil(self.clients.claim()));
self.addEventListener("fetch",function(event){
 const request=event.request,url=new URL(request.url);
 if(request.method!=="GET"||url.origin!==self.location.origin)return;
 const engine=url.pathname.endsWith("/index.wasm");
 const data=url.pathname.includes("/game-data/");
 const versioned=/\.(js|ttf|png)$/.test(url.pathname)&&url.searchParams.has("v");
 if(!engine&&!data&&!versioned)return;
 event.respondWith((async()=>{
  let cache;
  try{cache=await caches.open(engine?ENGINE_CACHE:DATA_CACHE);}catch(error){return fetch(request);}
  const key=new URL(request.url);
  if(engine)key.searchParams.set("engine",ENGINE_SHA256);
  const stored=await cache.match(key.href);
  if(stored)return stored;
  const response=await fetch(engine?new Request(request,{cache:"no-cache"}):request);
  // The downloader saves fragments only AFTER size and SHA-256 verification.
  // Avoid a second streaming copy for every fragment on the first download.
  if(response.ok&&!data){
   const copy=response.clone();
   event.waitUntil((async()=>{
    if(engine){
     const buffer=await copy.arrayBuffer();
     const sha=Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",buffer)),b=>b.toString(16).padStart(2,"0")).join("");
     if(sha!==ENGINE_SHA256)return;
     await cache.put(key.href,new Response(buffer,{headers:{"Content-Type":"application/wasm"}}));
    }else await cache.put(key.href,copy);
   })().catch(()=>{/* Optional cache failures must never block the game. */}));
  }
  return response;
 })());
});
