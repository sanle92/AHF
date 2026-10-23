import {config,json} from '@/lib/server';
export function GET(){ const c=config();return json({mode:c.demo?'demo':c.url&&c.key?'live':'setup',url:c.url,key:c.key,vapidPublic:c.vapidPublic,pushReady:!!(c.vapidPublic&&c.vapidPrivate&&c.vapidSubject),requiresMfa:true}); }
