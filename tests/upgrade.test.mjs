import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {moduleConfig} from '../lib/modules.ts';
import {PGlite} from '@electric-sql/pglite';
test('v0.3 workflows, record scope, private approvals, ledger and push revocation',async(t)=>{
 const db=new PGlite();
 t.after(()=>db.close());
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
 create schema auth;create schema storage;create table auth.users(id uuid primary key);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 create function auth.jwt() returns jsonb language sql stable as $$select jsonb_build_object('aal',current_setting('request.jwt.claim.aal',true))$$;
 grant usage on schema auth,public,storage to authenticated,anon,service_role;grant execute on function auth.uid() to authenticated,anon,service_role;
 create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text,owner_id text);alter table storage.objects enable row level security;grant select,insert,delete on storage.objects to authenticated;`);
 for(const f of ['001_workspace','002_require_mfa','003_planned_programmes','004_management_upgrade'])await db.exec(await readFile(new URL('../supabase/migrations/'+f+'.sql',import.meta.url),'utf8'));
 const rules=(await db.query('select * from module_rules')).rows;assert.equal(rules.length,Object.keys(moduleConfig).length);for(const rule of rules){assert.deepEqual(rule.read_roles,moduleConfig[rule.kind].read);assert.deepEqual(rule.fields,moduleConfig[rule.kind].fields);}
 const roles={admin:'administrator',secretary:'secretary',chair:'chairperson',treasurer:'treasurer',finance:'finance_officer',manager:'finance_manager',officer:'program_officer',other:'program_officer',volunteer:'volunteer',reviewer:'volunteer',auditor:'auditor'};
 const ids={};let n=1;for(const [name,role]of Object.entries(roles)){ids[name]='00000000-0000-4000-8000-'+String(n++).padStart(12,'0');await db.query('insert into auth.users values($1)',[ids[name]]);await db.query('insert into profiles(id,name,roles) values($1,$2,$3)',[ids[name],name,[role]]);}
 const as=async(name,aal='aal2')=>{await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claim.aal',$2,false)",[ids[name]||'',aal]);await db.exec('set role '+(name==='service'?'service_role':'authenticated'));};
 const day=(await db.query("select (now() at time zone 'Africa/Kampala')::date::text as value")).rows[0].value;
 const yearStart=day.slice(0,4)+'-01-01',yearEnd=day.slice(0,4)+'-12-31',nextWeek=new Date(Date.parse(day+'T12:00:00Z')+7*86400000).toISOString().slice(0,10);
 const create=async(kind,details={},extra={})=>(await db.query('select * from create_record_v3($1)',[{kind,title:'Test '+kind,amount:0,currency:'UGX',date:day,category:'General',description:'Evidence and justification for review',assignee:null,details,...extra}])).rows[0];
 const move=async(r,status,note='')=>(await db.query('select * from transition_record($1,$2,$3,$4)',[r.id,status,r.version,note])).rows[0];
 const approval=async(r)=>(await db.query('select * from approval_requests where record_id=$1 and status=\'Pending\'',[r.id])).rows[0];
 const decide=async(a,yes=true,note='Reviewed')=>(await db.query('select * from decide_approval($1,$2,$3)',[a.id,yes,note])).rows[0];
 const get=async(id)=>(await db.query('select * from records where id=$1',[id])).rows[0];
 let programme,budget,expense,account,payment,meeting,minutes,task;
 await t.test('programme membership scopes direct reads and files',async()=>{
  await as('admin');programme=await create('program',{objectives:'Deliver verified support'});const other=await create('program',{objectives:'Another programme'});await db.query('select set_program_member($1,$2,true)',[programme.id,ids.officer]);const activity=await create('activity',{}, {program_id:programme.id});const hidden=await create('activity',{}, {program_id:other.id});const beneficiary=await create('beneficiary',{need:'Private assessment'},{program_id:programme.id});
  await as('officer');assert.ok(await get(programme.id));assert.ok(await get(activity.id));assert.ok(await get(beneficiary.id));assert.equal(await get(hidden.id),undefined);
  await assert.rejects(()=>create('activity',{}, {program_id:other.id}),/Programme is not accessible/);
  await as('other');assert.equal(await get(activity.id),undefined);assert.equal(await get(beneficiary.id),undefined);
  await as('admin');await db.query('select set_program_member($1,$2,false)',[programme.id,ids.officer]);await as('officer');assert.equal(await get(activity.id),undefined);
 });
 await t.test('secretary workspace stays private while chair reviews only submitted minutes',async()=>{
  await as('secretary');meeting=await create('meeting',{reference:'AHF-MTG-001',meeting_type:'Leadership',starts_at:'2026-10-22T10:00:00+03:00',ends_at:'2026-10-22T11:00:00+03:00',agenda:[['Opening','Secretary','10']]});meeting=await move(meeting,'Scheduled');
  minutes=await create('minutes',{meeting_id:meeting.id,reference:'AHF-MIN-001',approver_id:ids.chair,discussions:[['Opening','Review delivery','Agree next actions']]});await db.query("insert into storage.objects(bucket_id,name,owner_id) values('ahf-private',$1,auth.uid()::text)",[minutes.id+'/minutes.pdf']);minutes=await move(minutes,'In review');
  await assert.rejects(()=>db.query('select * from edit_record($1,$2,$3)',[minutes.id,minutes.version,{...minutes,title:'Changed'}]),/locked/);
  await as('chair');assert.equal(await get(meeting.id),undefined);assert.equal(await get(minutes.id),undefined);assert.equal((await db.query('select * from storage.objects')).rows.length,0);await assert.rejects(()=>create('meeting'),/Access denied/);const a=await approval(minutes);assert.ok(a);assert.equal(a.snapshot.reference,'AHF-MIN-001');await decide(a);await assert.rejects(()=>decide(a),/Access denied/);
  await as('secretary');assert.equal((await get(minutes.id)).status,'Approved');await assert.rejects(()=>db.query('select * from edit_record($1,$2,$3)',[minutes.id,3,{...minutes,title:'Changed'}]),/locked/);
 });
 await t.test('budget approval separates requester, approver and recorded payment',async()=>{
  await as('treasurer');account=await create('account',{account_type:'Cash',opening_evidence:'Verified cash count'},{amount:1000000});account=await move(account,'Active');assert.equal(account.version,2);
  budget=await create('budget',{start_date:yearStart,end_date:yearEnd},{amount:400000,program_id:programme.id});budget=await move(budget,'Submitted');await assert.rejects(async()=>decide({id:(await approval(budget)).id}),/Access denied/);
  await as('manager');await decide(await approval(budget));
  await as('admin');expense=await create('expense',{budget_id:budget.id,payee:'Test supplier',purpose:'Verified programme materials'},{amount:60000,program_id:programme.id});expense=await move(expense,'Submitted');
  await as('treasurer');await decide(await approval(expense));assert.equal((await get(expense.id)).status,'Approved');assert.equal((await db.query('select sum(amount) balance from ledger_entries')).rows[0].balance,'1000000.00');await assert.rejects(async()=>move(await get(expense.id),'Paid'),/Transition not permitted/);
  await as('finance');payment=await create('payment',{expense_id:expense.id,account_id:account.id,method:'Cash',reference:'PAY-001',evidence:'Receipt signed by supplier'},{amount:30000,program_id:programme.id});await assert.rejects(()=>move(payment,'Paid'),/Attach payment evidence/);await db.query('insert into attachments(record_id,path,name) values($1,$2,$3)',[payment.id,payment.id+'/receipt.pdf','receipt.pdf']);payment=await move(payment,'Paid');assert.equal((await get(expense.id)).status,'Partly paid');assert.equal((await db.query('select sum(amount) balance from ledger_entries')).rows[0].balance,'970000.00');
  await assert.rejects(()=>move({...payment,version:1},'Reconciled'),/Record changed/);await assert.rejects(()=>db.query('delete from ledger_entries'),/permission denied/);
  await as('treasurer');payment=await move(payment,'Voided','Duplicate transaction correction');assert.equal((await get(expense.id)).status,'Approved');assert.equal((await db.query('select sum(amount) balance from ledger_entries')).rows[0].balance,'1000000.00');await assert.rejects(()=>move(payment,'Voided','Again'),/Transition not permitted/);
 });
 await t.test('pledges support partial receipts and documented reversals',async()=>{
  await as('treasurer');const donor=await create('donor',{donor_type:'Individual',consent:false});const pledge=await create('pledge',{donor_id:donor.id},{amount:100000});let donation=await create('donation',{donor_id:donor.id,pledge_id:pledge.id,account_id:account.id,method:'Cash'},{amount:25000});donation=await move(donation,'Received');assert.equal((await get(pledge.id)).status,'Partly fulfilled');await move(donation,'Voided','Receipt recorded twice');assert.equal((await get(pledge.id)).status,'Pledged');
  const mismatch=await create('donation',{donor_id:donor.id,pledge_id:pledge.id,account_id:account.id,method:'Cash'},{amount:100001});await assert.rejects(()=>move(mismatch,'Received'),/outstanding pledge/);
 });
 await t.test('advances, retirement, transfers and closed periods retain ledger integrity',async()=>{
  await as('treasurer');let advance=await create('advance',{account_id:account.id,budget_id:budget.id,purpose:'Field operations',accountable_person:ids.officer,retirement_due:nextWeek},{amount:50000,program_id:programme.id});advance=await move(advance,'Submitted');
  await as('manager');await decide(await approval(advance));await as('treasurer');advance=await get(advance.id);await db.query('insert into attachments(record_id,path,name) values($1,$2,$3)',[advance.id,advance.id+'/advance.pdf','advance.pdf']);advance=await move(advance,'Paid');
  let retirement=await create('retirement',{advance_id:advance.id,returned:10000,evidence:'Receipts verified'},{amount:40000,program_id:programme.id});await db.query('insert into attachments(record_id,path,name) values($1,$2,$3)',[retirement.id,retirement.id+'/receipts.pdf','receipts.pdf']);retirement=await move(retirement,'Submitted');
  await as('manager');await decide(await approval(retirement));assert.equal((await get(advance.id)).status,'Settled');
  await as('treasurer');let destination=await create('account',{account_type:'Cash',opening_evidence:'Verified empty box'});destination=await move(destination,'Active');let transfer=await create('transfer',{from_account_id:account.id,to_account_id:destination.id,reference:'TR-001'},{amount:100000});transfer=await move(transfer,'Submitted');await as('manager');await decide(await approval(transfer));await as('treasurer');transfer=await move(await get(transfer.id),'Posted');
  await assert.rejects(()=>move(destination,'Closed'),/Clear the recorded balance/);transfer=await move(transfer,'Voided','Transfer correction verified');
  assert.equal((await db.query('select sum(amount) balance from ledger_entries where account_id=$1',[account.id])).rows[0].balance,'960000.00');
  for(const [a,balance] of [[account,960000],[destination,0]]){let rec=await create('reconciliation',{account_id:a.id,statement_balance:balance,statement_reference:'STMT-001',start_date:yearStart,end_date:day});rec=await move(rec,'Submitted');await as('manager');await decide(await approval(rec));await as('treasurer');}
  let period=await create('period',{start_date:yearStart,end_date:day,evidence:'Both account reconciliations approved'});period=await move(period,'Closed');assert.equal(period.status,'Closed');
  const donor=await create('donor');const receipt=await create('donation',{donor_id:donor.id,account_id:account.id,method:'Cash'},{amount:1000});await assert.rejects(()=>move(receipt,'Received'),/financial period is closed/);
 });
 await t.test('thresholds, currencies and expired access are enforced by SQL',async()=>{
  await as('treasurer');let large=await create('budget',{start_date:yearStart,end_date:yearEnd},{amount:600000});large=await move(large,'Submitted');await as('manager');assert.equal(await approval(large),undefined);await as('chair');assert.ok(await approval(large));await decide(await approval(large),false,'Please provide a smaller allocation');
  await as('treasurer');const usd=await create('account',{account_type:'Bank',opening_evidence:'Verified USD statement'},{currency:'USD',amount:100.25,date:day});await move(usd,'Active');const donor=await create('donor');const wrong=await create('donation',{donor_id:donor.id,account_id:usd.id,method:'Bank transfer'},{currency:'EUR',amount:10,date:day});await assert.rejects(()=>move(wrong,'Received'),/same currency/);
  await assert.rejects(()=>create('account',{account_type:'Cash',opening_evidence:'Invalid whole currency'},{amount:1.25}),/amount_precision/);
  await db.exec('reset role');await db.query("update profiles set access_until=now()-interval '1 second' where id=$1",[ids.other]);await as('other');assert.equal((await db.query('select * from profiles')).rows.length,0);await assert.rejects(()=>create('task',{priority:'Normal'}),/Access denied/);
 });
 await t.test('tasks enforce reviewer, dependency, checklist, evidence and recurrence',async()=>{
  await as('admin');task=await create('task',{priority:'High',reviewer_id:ids.reviewer,evidence:'Completed handover',recurrence:'Weekly',checklist:[['Call contact','yes']]},{assignee:ids.volunteer});task=await move(task,'In progress');task=await move(task,'In review');
  await as('volunteer');await assert.rejects(()=>move(task,'Completed'),/Only the assigned reviewer/);
  await as('reviewer');assert.ok(await get(task.id));task=await move(task,'Completed');
  await as('admin');const recurred=(await db.query("select * from records where kind='task' and status='To do'")).rows;assert.equal(recurred.length,1);assert.equal(new Date(recurred[0].date).toISOString().slice(0,10),nextWeek);assert.equal(recurred[0].assignee,ids.volunteer);
 });
 await t.test('revoked membership cancels queued push and inbox access',async()=>{
  await as('volunteer');const sub={endpoint:'https://web.push.apple.com/test',keys:{p256dh:'a'.repeat(87),auth:'b'.repeat(22)}};await db.query("insert into push_subscriptions(user_id,endpoint,subscription,device_name) values(auth.uid(),$1,$2,'Phone')",[sub.endpoint,sub]);
  await as('admin');await create('task',{priority:'Normal'},{assignee:ids.volunteer});await as('service');const first=(await db.query('select * from claim_push_jobs()')).rows;assert.equal(first.length,1);await db.query("select finish_push_job($1,false,false,'HTTP 503')",[first[0].id]);await as('volunteer');assert.equal((await db.query('select * from notification_deliveries')).rows.length,1);assert.equal((await db.query('select retry_my_push() count')).rows[0].count,1);
  await db.exec('reset role');await db.query('update profiles set active=false where id=$1',[ids.volunteer]);
  await as('service');await db.query('select prepare_due_reminders()');const jobs=(await db.query('select * from claim_push_jobs()')).rows;assert.equal(jobs.length,0);
  await as('volunteer');assert.equal((await db.query('select * from notifications')).rows.length,0);assert.equal((await db.query('select * from records')).rows.length,0);
  await as('admin','aal1');assert.equal((await db.query('select * from records')).rows.length,0);await assert.rejects(()=>create('task',{priority:'Normal'}),/Access denied/);
  await as('auditor');await assert.rejects(()=>create('payment'),/Access denied/);assert.ok((await db.query('select * from ledger_entries')).rows.length>0);
 });
});
