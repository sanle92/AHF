import {test} from 'node:test';
import assert from 'node:assert/strict';
import {verifyTotp} from '../lib/auth-client.ts';
import {hasSecondFactor} from '../lib/assurance.ts';
test('MFA requires a fresh challenge and uses the verified replacement session',async()=>{
 const calls:{url:string;body:any}[]=[];
 const mock=async(url:RequestInfo|URL,init?:RequestInit)=>{calls.push({url:String(url),body:JSON.parse(String(init?.body))});return new Response(JSON.stringify(calls.length===1?{id:'challenge-123'}:{access_token:'verified-token',refresh_token:'rotated-refresh',expires_in:3600}),{status:200});};
 const result=await verifyTotp({url:'https://project.supabase.co',key:'public-key'},'old-token','factor-123','123456',mock as typeof fetch);
 assert.equal(calls[0].url,'https://project.supabase.co/auth/v1/factors/factor-123/challenge');
 assert.deepEqual(calls[1].body,{challenge_id:'challenge-123',code:'123456'});
 assert.equal(result.access_token,'verified-token');assert.equal(result.refresh_token,'rotated-refresh');assert.ok(result.expires_at>Date.now()/1000);
});
test('invalid codes and failed challenges never verify or elevate a session',async()=>{
 let calls=0;const mock=async()=>{calls++;return new Response('{}',{status:400});};
 await assert.rejects(()=>verifyTotp({url:'https://project.supabase.co',key:'public'},'token','factor','abc',mock as typeof fetch));assert.equal(calls,0);
 await assert.rejects(()=>verifyTotp({url:'https://project.supabase.co',key:'public'},'token','factor','123456',mock as typeof fetch));assert.equal(calls,1);
});
test('assurance decoding rejects malformed or password-only claims',()=>{
 const token=(aal:string)=>'header.'+btoa(JSON.stringify({aal}))+'.signature';
 assert.equal(hasSecondFactor(''),false);assert.equal(hasSecondFactor('broken.invalid.token'),false);assert.equal(hasSecondFactor(token('aal1')),false);assert.equal(hasSecondFactor(token('aal2')),true);
 // Claim decoding is never a signature verification substitute. /user and RLS
 // perform the actual authenticated verification before private data is read.
});
