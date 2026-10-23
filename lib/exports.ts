import type {RecordItem} from './domain.ts';
export function calendarFile(r:RecordItem){
 const esc=(v:unknown)=>String(v||'').replace(/\\/g,'\\\\').replace(/\r?\n/g,'\\n').replace(/;/g,'\\;').replace(/,/g,'\\,');
 const stamp=(v:unknown)=>{const s=String(v||'');const d=new Date(s.endsWith('Z')||/[+-]\d\d:\d\d$/.test(s)?s:s+'+03:00');if(Number.isNaN(d.getTime()))throw Error('Add a valid start and end time first.');return d.toISOString().replace(/[-:]/g,'').replace(/\.\d{3}Z/,'Z');};
 const start=stamp(r.details.starts_at),end=stamp(r.details.ends_at);if(end<=start)throw Error('End time must follow start time.');
 const lines=['BEGIN:VCALENDAR','VERSION:2.0','PRODID:-//Aminia Hope Foundation//Workspace//EN','CALSCALE:GREGORIAN','METHOD:PUBLISH','BEGIN:VEVENT','UID:'+r.id+'@aminiahope.workspace','SEQUENCE:'+r.version,'DTSTAMP:'+new Date(r.updated_at).toISOString().replace(/[-:]/g,'').replace(/\.\d{3}Z/,'Z'),'DTSTART:'+start,'DTEND:'+end,'SUMMARY:'+esc(r.title),'DESCRIPTION:'+esc(r.description),'LOCATION:'+esc(r.details.location),'STATUS:'+(r.status==='Cancelled'?'CANCELLED':'CONFIRMED')];
 if(Number(r.details.reminder_minutes)>0)lines.push('BEGIN:VALARM','ACTION:DISPLAY','DESCRIPTION:Meeting reminder','TRIGGER:-PT'+Math.floor(Number(r.details.reminder_minutes))+'M','END:VALARM');
 if(['Weekly','Monthly'].includes(String(r.details.recurrence)))lines.push('RRULE:FREQ='+(r.details.recurrence==='Weekly'?'WEEKLY':'MONTHLY'));
 lines.push('END:VEVENT','END:VCALENDAR');
 return lines.map(line=>{let out='',part='',bytes=0;for(const ch of line){const n=new TextEncoder().encode(ch).length;if(bytes+n>75){out+=part+'\r\n';part=' ';bytes=1;}part+=ch;bytes+=n;}return out+part;}).join('\r\n')+'\r\n';
}
export function csv(rows:unknown[][]){const esc=(v:unknown)=>{const s=String(v??'');return '"'+(/^[\s]*[=+@\-]/.test(s)?"'":'')+s.replace(/"/g,'""')+'"';};return '\uFEFF'+rows.map(row=>row.map(esc).join(',')).join('\r\n');}
export function download(name:string,content:string,type='text/plain;charset=utf-8'){const url=URL.createObjectURL(new Blob([content],{type}));const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
