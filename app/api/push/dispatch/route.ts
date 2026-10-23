import {config,json} from '@/lib/server';
import {sendPush} from '@/lib/push';
export async function POST(request:Request){
 const c=config();if(!c.dispatchSecret||request.headers.get('Authorization')!==`Bearer ${c.dispatchSecret}`)return json({error:'Unauthorized'},401);
 if(!c.serviceKey)return json({error:'Worker backend not configured.'},503);
 const call=async(path:string,body:unknown)=>{const r=await fetch(c.url+'/rest/v1/rpc/'+path,{method:'POST',headers:{apikey:c.serviceKey,Authorization:`Bearer ${c.serviceKey}`,'Content-Type':'application/json'},body:JSON.stringify(body)});if(!r.ok)throw new Error('Job operation failed.');return r.json<any>();};
 try{await call('prepare_due_reminders',{});const jobs=await call('claim_push_jobs',{});let sent=0;for(const job of jobs){let success=false;let expired=false;let errorCode:string|null=null;try{await sendPush(job.subscription,'AHF Workspace','You have a new update. Open your workspace to review it.','/?notification='+job.notification_id);success=true;sent++;}catch(e){const code=(e as {statusCode?:number}).statusCode;expired=[404,410].includes(code||0);errorCode=code?'HTTP '+code:'Push request failed';}await call('finish_push_job',{job_id:job.id,succeeded:success,expired,error_code:errorCode});}return json({sent});}catch{return json({error:'Push dispatch failed.'},500);}
}
