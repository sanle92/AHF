import webpush from 'web-push';
import {config} from './server';
export async function sendPush(subscription:webpush.PushSubscription,title:string,body:string,url='/'){
 const c=config();if(!c.vapidPublic||!c.vapidPrivate||!c.vapidSubject)throw new Error('Push is not configured.');
 return webpush.sendNotification(subscription,JSON.stringify({title,body,url}),{TTL:3600,vapidDetails:{subject:c.vapidSubject,publicKey:c.vapidPublic,privateKey:c.vapidPrivate}});
}
