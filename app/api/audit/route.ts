import {authorize,db,json} from '@/lib/server';
export async function GET(request:Request){try{const {token}=await authorize(request);return json(await db('/rest/v1/audit_events?select=*&order=created_at.desc&limit=100',token));}catch(e){return json({error:(e as Error).message},401);}}
