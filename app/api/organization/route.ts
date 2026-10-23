import {authorize,db,json,sameOrigin} from '@/lib/server';
export async function POST(request:Request){try{sameOrigin(request);const {token}=await authorize(request);return json(await db('/rest/v1/rpc/initialize_programme_areas',token,{method:'POST',body:'{}'}));}catch(e){return json({error:(e as Error).message},400);}}
