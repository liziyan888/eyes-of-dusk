"use strict";
const CACHE_NAME="eyes-game-data-v1";
self.addEventListener("install",function(event){event.waitUntil(self.skipWaiting());});
self.addEventListener("activate",function(event){
 event.waitUntil((async function(){
  await self.clients.claim();
  const keys=await caches.keys();
  await Promise.all(keys.filter(function(key){return key.startsWith("eyes-game-")&&key!==CACHE_NAME;}).map(function(key){return caches.delete(key);}));
 })());
});
self.addEventListener("fetch",function(event){
 const request=event.request;
 if(request.method!=="GET"||new URL(request.url).origin!==self.location.origin)return;
 const url=new URL(request.url);
 const asset=url.pathname.includes("/game-data/")||/\.(wasm|js|png)$/.test(url.pathname);
 if(!asset)return;
 event.respondWith((async function(){
  const cache=await caches.open(CACHE_NAME);
  const stored=await cache.match(request);
  if(stored)return stored;
  const response=await fetch(request);
  if(response.ok){
   const copy=response.clone();
   event.waitUntil(cache.put(request,copy).catch(function(){/* Optional cache quota must never block the game. */}));
  }
  return response;
 })());
});
