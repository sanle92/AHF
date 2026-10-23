import {authorize,db,json,sameOrigin} from '@/lib/server';
import {validUuid} from '@/lib/domain';
export async function GET(r:Request){try{const {token}=await authorize(r);return json(await db('/rest/v1/approval_requests?select=*&order=created_at.desc&limit=500',token));}catch(e){return json({error:(e as Error).message},401);}}
export async function POST(r:Request){try{sameOrigin(r);const {token}=await authorize(r),v=await r.json<any>();if(!validUuid(v.id)||typeof v.approve!=='boolean'||typeof v.note!=='string'||v.note.length>5000)throw Error('Invalid review.');return json(await db('/rest/v1/rpc/decide_approval',token,{method:'POST',body:JSON.stringify({approval_id:v.id,approve:v.approve,note:v.note})}));}catch(e){return json({error:(e as Error).message},400);}}
