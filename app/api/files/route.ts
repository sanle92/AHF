import {authorize,config,db,json,sameOrigin} from '@/lib/server';
export async function POST(request:Request){try{
 sameOrigin(request);const {token}=await authorize(request);const data=await request.formData();const file=data.get('file');const recordId=String(data.get('record_id')||'');
 if(!(file instanceof File)||file.size>10*1024*1024||file.size===0||!['application/pdf','image/jpeg','image/png'].includes(file.type))return json({error:'Choose a PDF, JPG, or PNG up to 10 MB.'},400);
 if(!/^[0-9a-f-]{36}$/i.test(recordId))return json({error:'Invalid record.'},400);
 const rows=await db(`/rest/v1/records?id=eq.${recordId}&select=id`,token);if(!rows.length)return json({error:'Access denied.'},403);
 const ext=file.type==='application/pdf'?'pdf':file.type==='image/png'?'png':'jpg';const path=`${recordId}/${crypto.randomUUID()}.${ext}`;const c=config();
 const res=await fetch(`${c.url}/storage/v1/object/ahf-private/${path}`,{method:'POST',headers:{apikey:c.key,Authorization:`Bearer ${token}`,'Content-Type':file.type},body:await file.arrayBuffer()});
 if(!res.ok)throw new Error('Upload failed. Check your access.');
 // Metadata is inserted under the same RLS constraints as the file.
 try{const saved=await db('/rest/v1/attachments',token,{method:'POST',headers:{Prefer:'return=representation'},body:JSON.stringify({record_id:recordId,path,name:file.name.slice(0,180)})});return json(saved[0],201);}catch(e){await fetch(`${c.url}/storage/v1/object/ahf-private`,{method:'DELETE',headers:{apikey:c.key,Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({prefixes:[path]})});throw e;}
 }catch(e){return json({error:(e as Error).message},400);}}
export async function GET(request:Request){try{const {token}=await authorize(request);const id=new URL(request.url).searchParams.get('record_id');if(!id||!/^[0-9a-f-]{36}$/i.test(id))return json({error:'Invalid record.'},400);const files=await db(`/rest/v1/attachments?record_id=eq.${id}&select=*`,token);const c=config();const signed=await Promise.all(files.map(async(f:{path:string})=>{const response=await fetch(`${c.url}/storage/v1/object/sign/ahf-private/${f.path}`,{method:'POST',headers:{apikey:c.key,Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({expiresIn:60})});if(!response.ok)throw new Error('Unable to open file.');const s=await response.json<any>();return {...f,url:c.url+'/storage/v1'+s.signedURL};}));return json(signed);}catch(e){return json({error:(e as Error).message},400);}}
