import handler from 'vinext/server/fetch-handler';
const worker = {
 async fetch(request:Request, env:Cloudflare.Env, ctx:ExecutionContext){
  const response=await handler.fetch(request,env,ctx);
  const result=new Response(response.body,response);
  result.headers.set('X-Content-Type-Options','nosniff');
  result.headers.set('X-Frame-Options','DENY');
  result.headers.set('Referrer-Policy','no-referrer');
  result.headers.set('Permissions-Policy','camera=(), microphone=(), geolocation=()');
  result.headers.set('X-Robots-Tag','noindex, nofollow');
  if(response.headers.get('Content-Type')?.includes('text/html')||new URL(request.url).pathname.startsWith('/api/'))result.headers.set('Cache-Control','private, no-store');
  return result;
 }
};
export default worker;
