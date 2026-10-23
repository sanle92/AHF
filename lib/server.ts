import {workflowErrors} from './workflow-errors';
import { env } from 'cloudflare:workers';
import { type Profile } from './domain';
import { hasSecondFactor } from './assurance';
export function config() {
 const e=env as unknown as Record<string,string|undefined>;
 return {url:e.AHF_SUPABASE_URL||'',key:e.AHF_SUPABASE_ANON_KEY||'',demo:e.AHF_DEMO_MODE==='true',vapidPublic:e.AHF_VAPID_PUBLIC_KEY||'',vapidPrivate:e.AHF_VAPID_PRIVATE_KEY||'',vapidSubject:e.AHF_VAPID_SUBJECT||'',serviceKey:e.AHF_SUPABASE_SERVICE_ROLE_KEY||'',dispatchSecret:e.AHF_PUSH_DISPATCH_SECRET||''};
}
export function json(data:unknown,status=200) { return Response.json(data,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}}); }
// This is the JSON transport boundary. Callers validate writes and DB constraints
// validate persisted data; the transport deliberately accepts heterogeneous rows.
export async function db(path:string,token:string,init:RequestInit={}):Promise<any> {
 const c=config();
 const response=await fetch(c.url+path,{...init,headers:{apikey:c.key,Authorization:`Bearer ${token}`,'Content-Type':'application/json',...init.headers},cache:'no-store'});
 if(!response.ok) {
  const data=await response.json<{message?:string}>().catch(()=>({message:undefined}));
  // Return known workflow errors; never leak database internals or SQL.
  const known=['Record changed; reload and try again.','Transition not permitted.','Access denied.','Cannot approve your own request.','Record is locked.'];
  throw new Error(data.message&&(known.includes(data.message)||workflowErrors.includes(data.message))?data.message:'The operation could not be completed. Check your access and try again.');
 }
 return response.status===204?null:response.json();
}
export async function authorize(request:Request) {
 const c=config();
 if(!c.url||!c.key||c.demo) throw new Error('Private backend is not enabled.');
 const token=request.headers.get('Authorization')?.replace(/^Bearer /,'');
 if(!token) throw new Error('Sign in required.');
 const user=await db('/auth/v1/user',token);
 if(!hasSecondFactor(token))throw new Error('Two-step verification required.');
 const profiles=await db(`/rest/v1/profiles?id=eq.${encodeURIComponent(user.id)}&select=*`,token);
 const profile=profiles[0] as Profile|undefined;
 if(!profile?.active) throw new Error('Access denied.');
 return {token,profile};
}
export function sameOrigin(request:Request) {
 const origin=request.headers.get('Origin');
 if(origin&&origin!==new URL(request.url).origin) throw new Error('Access denied.');
}
