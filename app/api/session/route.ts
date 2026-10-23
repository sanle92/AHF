import {authorize,db,json} from '@/lib/server';
export async function GET(request:Request){try{const {token,profile}=await authorize(request);const team=await db('/rest/v1/profiles?select=id,name,roles,active&active=eq.true',token);const members=await db('/rest/v1/program_members?select=*',token);return json({profile,team,members});}catch(e){return json({error:(e as Error).message},401);}}
