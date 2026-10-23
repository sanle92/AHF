import {authorize,db,json,sameOrigin} from '@/lib/server';
import {validUuid} from '@/lib/domain';
export async function GET(r:Request){try{const {token}=await authorize(r);return json(await db('/rest/v1/program_members?select=*',token));}catch(e){return json({error:(e as Error).message},401);}}
export async function POST(r:Request){try{sameOrigin(r);const {token}=await authorize(r),v=await r.json<any>();if(!validUuid(v.program_id)||!validUuid(v.user_id)||typeof v.enabled!=='boolean')throw Error('Invalid programme membership.');await db('/rest/v1/rpc/set_program_member',token,{method:'POST',body:JSON.stringify({pid:v.program_id,uid:v.user_id,enabled:v.enabled})});return json({ok:true});}catch(e){return json({error:(e as Error).message},400);}}
