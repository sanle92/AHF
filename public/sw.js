/* Intentionally no fetch caching: confidential responses must stay network-only.
   Offline navigation shows a static, non-sensitive page. */
const CACHE='ahf-shell-v3';
self.addEventListener('install',event=>{event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(['/offline.html','/icons/icon-192.png'])));self.skipWaiting();});
self.addEventListener('activate',event=>{event.waitUntil(Promise.all([caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))),self.clients.claim()]));});
self.addEventListener('fetch',event=>{if(event.request.mode==='navigate')event.respondWith(fetch(event.request).catch(()=>caches.match('/offline.html')));});
self.addEventListener('push',event=>{let data={title:'AHF Workspace',body:'You have a new update.'};try{Object.assign(data,event.data.json());}catch{}event.waitUntil(self.registration.showNotification(data.title,{body:data.body,icon:'/icons/icon-192.png',badge:'/icons/icon-192.png',data:{url:typeof data.url==='string'&&/^\/\?notification=[0-9a-f-]{36}$/i.test(data.url)?data.url:'/'}}));});
self.addEventListener('notificationclick',event=>{event.notification.close();event.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(async clients=>{for(const client of clients){if(new URL(client.url).origin===self.location.origin){await client.navigate(new URL(event.notification.data?.url||'/',self.location.origin).href);await client.focus();return;}}return self.clients.openWindow(event.notification.data?.url||'/');}));});
