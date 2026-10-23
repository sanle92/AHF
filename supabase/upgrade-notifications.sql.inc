alter table public.notifications add column event_type text not null default 'updates';
alter table public.notifications add column approval_id uuid references public.approval_requests(id);
alter table public.notifications add column dedupe_key text unique;
alter table public.push_jobs add column last_error text;
create table public.notification_preferences(user_id uuid primary key references profiles(id) on delete cascade,assignments boolean not null default true,approvals boolean not null default true,reminders boolean not null default true,updates boolean not null default true,push_enabled boolean not null default true);
alter table public.notification_preferences enable row level security;
create policy own_preferences on public.notification_preferences for all to authenticated using(user_id=auth.uid() and public.is_active()) with check(user_id=auth.uid() and public.is_active());
create table public.notification_deliveries(id uuid primary key default gen_random_uuid(),user_id uuid not null references profiles(id),subscription_id uuid references push_subscriptions(id) on delete set null,notification_id uuid references notifications(id),outcome text not null,error_code text,created_at timestamptz not null default now());
alter table public.notification_deliveries enable row level security;
create policy own_deliveries on public.notification_deliveries for select to authenticated using(user_id=auth.uid() and public.is_active());
create table public.dispatch_health(id boolean primary key default true check(id),last_run timestamptz,claimed integer not null default 0);
insert into dispatch_health(id) values(true);
alter table public.dispatch_health enable row level security;
create policy admin_health on public.dispatch_health for select to authenticated using(public.has_role(array['administrator','operations_manager','executive_director']));
create function public.recipient_record_access(rid uuid,uid uuid) returns boolean language plpgsql stable security definer set search_path=public as $$
declare r records;p profiles;own boolean;member boolean;
begin
 select * into p from profiles where id=uid and active and (access_until is null or access_until>now());if not found then return false;end if;
 select * into r from records where id=rid;if not found or not exists(select 1 from module_rules where kind=r.kind and read_roles&&p.roles) then return false;end if;
 own:=r.created_by=uid or r.assignee=uid or uid=any(r.collaborators);member:=exists(select 1 from program_members where user_id=uid and program_id in(r.program_id,case when r.kind='program' then r.id else null end));
 if r.kind in ('meeting','minutes','resolution','correspondence','member') then return p.roles&&array['secretary','administrator'];end if;
 if r.kind='beneficiary' then return own or member;end if;
 if r.kind in ('task','document','program','activity','indicator') then return own or member or p.roles&&array['administrator','executive_director','operations_manager'];end if;
 if r.kind in ('expense','budget') then return own or (r.kind='budget' and member) or p.roles&&array['treasurer','finance_manager','finance_officer','auditor'];end if;
 return true;
end $$;
create function public.recipient_approval_access(aid uuid,uid uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from approval_requests a join profiles p on p.id=uid and p.active and (p.access_until is null or p.access_until>now()) where a.id=aid and a.requested_by<>uid and (a.assigned_to is null or a.assigned_to=uid) and
 case when a.record_kind='minutes' then p.roles&&array['chairperson','vice_chairperson'] when a.amount>coalesce((select (value->>a.currency)::numeric from organization_settings where key='approval_limits'),0) then p.roles&&array['chairperson','vice_chairperson'] else p.roles&&array['chairperson','vice_chairperson','treasurer','finance_manager','finance_approver'] end) $$;
create function public.recipient_notice_access(nid uuid,uid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from notifications n where n.id=nid and n.user_id=uid and (recipient_record_access(n.record_id,uid) or recipient_approval_access(n.approval_id,uid)))$$;
drop policy notifications_read on public.notifications;
create policy scoped_notifications_read on public.notifications for select to authenticated using(public.is_active() and user_id=auth.uid() and public.recipient_notice_access(id,auth.uid()));
-- Recipient checks happen before creation and again at dispatch, so a later role
-- change revokes both the inbox item and queued device delivery.
create function public.queue_notice(uid uuid,rid uuid,event text,key text,aid uuid default null) returns void language plpgsql security definer set search_path=public as $$
declare notice uuid;p notification_preferences;enabled boolean:=true;
begin
 if not (recipient_record_access(rid,uid) or recipient_approval_access(aid,uid)) then return;end if;
 select * into p from notification_preferences where user_id=uid;
 if found then enabled:=case event when 'assignments' then p.assignments when 'approvals' then p.approvals when 'reminders' then p.reminders else p.updates end;end if;
 if not enabled then return;end if;
 insert into notifications(user_id,record_id,approval_id,event_type,title,body,dedupe_key) values(uid,rid,aid,event,'AHF Workspace',case event when 'approvals' then 'An item is ready for your review.' when 'reminders' then 'An assigned item is due soon or overdue.' when 'assignments' then 'You have a new assignment.' else 'An item you are following has changed.' end,key) on conflict(dedupe_key) do nothing returning id into notice;
 if notice is not null and coalesce(p.push_enabled,true) then insert into push_jobs(notification_id,subscription_id) select notice,id from push_subscriptions where user_id=uid;end if;
end $$;
create or replace function public.record_event() returns trigger language plpgsql security definer set search_path=public as $$
declare uid uuid;
begin
 insert into audit_events(record_id,actor_id,action,old_status,new_status,old_data,new_data) values(new.id,auth.uid(),case when TG_OP='INSERT' then 'Created' when old.status is distinct from new.status then 'Status changed' else 'Edited' end,case when TG_OP='UPDATE' then old.status else null end,new.status,case when TG_OP='UPDATE' then to_jsonb(old) else null end,to_jsonb(new));
 for uid in select distinct x from unnest(array_append(new.collaborators,new.assignee)) x where x is not null and x<>auth.uid() loop
  perform queue_notice(uid,new.id,case when TG_OP='INSERT' or old.assignee is distinct from new.assignee or old.collaborators is distinct from new.collaborators then 'assignments' else 'updates' end,'record:'||new.id||':'||new.version||':'||uid);
 end loop;
 if TG_OP='UPDATE' and new.created_by<>auth.uid() then perform queue_notice(new.created_by,new.id,'updates','owner:'||new.id||':'||new.version);end if;
 return new;
end $$;
create function public.approval_event() returns trigger language plpgsql security definer set search_path=public as $$
declare p record;
begin
 for p in select id from profiles where active loop if recipient_approval_access(new.id,p.id) then perform queue_notice(p.id,new.record_id,'approvals','approval:'||new.id||':'||p.id,new.id);end if;end loop;
 return new;
end $$;
create trigger approval_event after insert on public.approval_requests for each row execute function public.approval_event();
drop function public.claim_push_jobs();
create function public.claim_push_jobs() returns table(id uuid,subscription jsonb,user_id uuid,subscription_id uuid,notification_id uuid) language plpgsql security definer set search_path=public as $$
begin
 update dispatch_health set last_run=now() where dispatch_health.id=true;
 return query with ready as (
 select j.id from push_jobs j join notifications n on n.id=j.notification_id join push_subscriptions s on s.id=j.subscription_id
 left join notification_preferences p on p.user_id=s.user_id
 where not j.done and j.attempts<5 and j.available_at<=now() and coalesce(p.push_enabled,true) and recipient_notice_access(n.id,s.user_id)
 order by j.available_at limit 20 for update of j skip locked
 ), claimed as (update push_jobs j set attempts=j.attempts+1,available_at=now()+interval '2 minutes' where j.id in(select ready.id from ready) returning j.id,j.subscription_id,j.notification_id)
 select c.id,s.subscription,s.user_id,s.id,c.notification_id from claimed c join push_subscriptions s on s.id=c.subscription_id;
end $$;
drop function public.finish_push_job(uuid,boolean,boolean);
create function public.finish_push_job(job_id uuid,succeeded boolean,expired boolean,error_code text default null) returns void language plpgsql security definer set search_path=public as $$
declare j push_jobs;uid uuid;
begin
 select * into j from push_jobs where id=job_id for update;if not found then return;end if;
 select user_id into uid from push_subscriptions where id=j.subscription_id;
 insert into notification_deliveries(user_id,subscription_id,notification_id,outcome,error_code) values(uid,j.subscription_id,j.notification_id,case when succeeded then 'Accepted by push service' else 'Failed' end,left(error_code,100));
 if expired then delete from push_subscriptions where id=j.subscription_id;else update push_jobs set done=succeeded,last_error=left(error_code,100),available_at=now()+interval '5 minutes' where id=job_id;end if;
end $$;
create function public.prepare_due_reminders() returns integer language plpgsql security definer set search_path=public as $$
declare r records;uid uuid;due timestamptz;added integer:=0;key text;
begin
 for r in select * from records where kind in ('task','meeting','correspondence','interaction','advance') and status not in ('Completed','Cancelled','Closed','Held','Settled','Voided') loop
  due:=case when r.kind='meeting' then (r.details->>'starts_at')::timestamptz when r.kind='correspondence' then ((r.details->>'response_due')||'T09:00:00+03:00')::timestamptz when r.kind='advance' then ((r.details->>'retirement_due')||'T09:00:00+03:00')::timestamptz else (r.date||'T09:00:00+03:00')::timestamptz end;
  if due is null or due>now()+make_interval(mins=>coalesce((r.details->>'reminder_minutes')::integer,60)) or due<now()-interval '30 days' then continue;end if;
  for uid in select distinct x from unnest(array_append(r.collaborators,r.assignee)) x where x is not null loop
   key:='due:'||r.id||':'||uid||':'||due::text||':'||(now() at time zone 'Africa/Kampala')::date;
   perform queue_notice(uid,r.id,'reminders',key);added:=added+1;
  end loop;
 end loop;return added;
end $$;
