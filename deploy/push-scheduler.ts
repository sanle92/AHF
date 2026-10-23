// Deploy separately with deploy/wrangler.scheduler.jsonc.
const scheduler = {
 async scheduled(_event:ScheduledEvent,env:{AHF_APP_URL:string;AHF_PUSH_DISPATCH_SECRET:string},ctx:ExecutionContext){
  ctx.waitUntil((async()=>{const response=await fetch(new URL('/api/push/dispatch',env.AHF_APP_URL),{method:'POST',headers:{Authorization:`Bearer ${env.AHF_PUSH_DISPATCH_SECRET}`}});if(!response.ok)throw new Error('Push dispatch failed');})());
 }
};
export default scheduler;
