-- Apply to a NEW, PRIVATE Supabase project. No public website uses this project.
begin;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null check(length(name) between 1 and 100),
 roles text[] not null default '{}', active boolean not null default true,
 check(roles <@ array['chairperson','vice_chairperson','administrator','treasurer','secretary','program_officer','volunteer']::text[])
);
alter table public.profiles enable row level security;
create function public.is_active() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and active) $$;
create function public.has_role(wanted text[]) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from profiles where id=auth.uid() and active and roles && wanted) $$;
create policy team_read on public.profiles for select to authenticated using(public.is_active());
-- No client inserts/updates: staff membership is provisioned by the project owner.
create function public.can_read_kind(k text) returns boolean language sql stable security definer set search_path=public as $$
 select public.is_active() and case
 when k='beneficiary' then public.has_role(array['administrator','program_officer'])
 when k in ('donation','pledge','budget','expense','donor') then public.has_role(array['chairperson','vice_chairperson','administrator','treasurer'])
 else true end $$;
create function public.can_write_kind(k text) returns boolean language sql stable security definer set search_path=public as $$
 select public.can_read_kind(k) and case
 when k='beneficiary' then public.has_role(array['administrator','program_officer'])
 when k in ('donation','pledge','budget','expense','donor') then public.has_role(array['administrator','treasurer'])
 when k in ('meeting','minutes','resolution','correspondence') then public.has_role(array['administrator','secretary'])
 else public.has_role(array['administrator','program_officer','secretary','chairperson','vice_chairperson']) end $$;
create table public.records (
 id uuid primary key default gen_random_uuid(),
 kind text not null check(kind in ('program','activity','beneficiary','donor','donation','pledge','budget','expense','meeting','minutes','resolution','correspondence','task','document')),
 title text not null check(length(title) between 3 and 180),
 status text not null, amount bigint not null default 0 check(amount between 0 and 1000000000000),
 date date not null, category text not null default 'General' check(length(category)<=100),
 description text not null default '' check(length(description)<=10000),
 assignee uuid references public.profiles(id), created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 version integer not null default 1, details jsonb not null default '{}'
);
create index records_kind_date on public.records(kind,date);
create index records_assignee on public.records(assignee);
alter table public.records enable row level security;
create policy records_read on public.records for select to authenticated using(public.can_read_kind(kind));
create policy records_insert on public.records for insert to authenticated with check(public.can_write_kind(kind) and created_by=auth.uid());
create function public.guard_new_record() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.status <> (case when new.kind in ('expense','minutes') then 'Draft' when new.kind='donation' then 'Received' when new.kind='pledge' then 'Pledged' when new.kind='beneficiary' then 'Open' else 'Active' end)
 or new.details <> '{}'::jsonb or new.version<>1 then raise exception 'Invalid initial record.'; end if;
 new.created_at=now();new.updated_at=now();return new;
end $$;
create trigger guard_new_record before insert on public.records for each row execute function public.guard_new_record();
create table public.audit_events (
 id uuid primary key default gen_random_uuid(), record_id uuid not null references public.records(id),
 actor_id uuid references public.profiles(id), action text not null, old_status text, new_status text,old_data jsonb,new_data jsonb,
 created_at timestamptz not null default now()
);
alter table public.audit_events enable row level security;
create policy audit_read on public.audit_events for select to authenticated using(public.has_role(array['chairperson','vice_chairperson','administrator']) and exists(select 1 from records where id=record_id and public.can_read_kind(kind)));
create table public.notifications (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,
 record_id uuid references public.records(id),title text not null default 'Workspace update',body text not null default 'An item needs your attention.',read_at timestamptz,created_at timestamptz not null default now()
);
alter table public.notifications enable row level security;
create policy notifications_read on public.notifications for select to authenticated using(user_id=auth.uid() and public.is_active() and (record_id is null or exists(select 1 from records where id=record_id and public.can_read_kind(kind))));
create policy notifications_update on public.notifications for update to authenticated using(user_id=auth.uid() and public.is_active()) with check(user_id=auth.uid() and public.is_active());
create table public.push_subscriptions (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,
 endpoint text not null check(endpoint ~ '^https://([a-zA-Z0-9-]+\.)*(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|web\.push\.apple\.com|wns\.windows\.com)/'),
 subscription jsonb not null check((subscription->>'endpoint'=endpoint and jsonb_typeof(subscription->'keys')='object' and length(subscription->'keys'->>'p256dh') between 40 and 200 and length(subscription->'keys'->>'auth') between 10 and 100 and length(subscription::text)<8192) is true),
 device_name text not null check(length(device_name) between 1 and 80),created_at timestamptz not null default now(),unique(user_id,endpoint)
);
alter table public.push_subscriptions enable row level security;
create policy devices_own on public.push_subscriptions for all to authenticated using(user_id=auth.uid() and public.is_active()) with check(user_id=auth.uid() and public.is_active());
create table public.push_jobs (
 id uuid primary key default gen_random_uuid(),notification_id uuid not null references public.notifications(id) on delete cascade,
 subscription_id uuid not null references public.push_subscriptions(id) on delete cascade,
 attempts integer not null default 0, available_at timestamptz not null default now(),done boolean not null default false,
 unique(notification_id,subscription_id)
);
alter table public.push_jobs enable row level security;
-- No authenticated policies: only the service worker may claim jobs.
create function public.record_event() returns trigger language plpgsql security definer set search_path=public as $$
declare recipient record;notice uuid;
begin
 insert into audit_events(record_id,actor_id,action,old_status,new_status,old_data,new_data) values(new.id,auth.uid(),case when TG_OP='INSERT' then 'Created' when old.status is distinct from new.status then 'Status changed' else 'Edited' end,case when TG_OP='UPDATE' then old.status else null end,new.status,case when TG_OP='UPDATE' then to_jsonb(old) else null end,to_jsonb(new));
 for recipient in select p.id from profiles p where p.active and (
  (p.id=new.assignee and p.id<>auth.uid()) or
  (new.kind='expense' and new.status='Pending' and p.id<>new.created_by and p.roles && array['chairperson','vice_chairperson']) or
  (new.kind='minutes' and new.status='In review' and p.id<>new.created_by and p.roles && array['chairperson','vice_chairperson']) or
  (TG_OP='UPDATE' and new.created_by=p.id and p.id<>auth.uid())
 ) loop
  insert into notifications(user_id,record_id,title,body) values(recipient.id,new.id,'Workspace update','An item has been assigned or updated. Open it to review.') returning id into notice;
  insert into push_jobs(notification_id,subscription_id) select notice,id from push_subscriptions where user_id=recipient.id;
 end loop;
 return new;
end $$;
create trigger record_event after insert or update on public.records for each row execute function public.record_event();
create function public.transition_record(record_id uuid,target_status text,expected_version integer) returns public.records language plpgsql security definer set search_path=public as $$
declare r public.records;allowed boolean:=false;
begin
 select * into r from records where id=record_id for update;
 if not found or not public.can_read_kind(r.kind) then raise exception 'Access denied.';end if;
 if r.version<>expected_version then raise exception 'Record changed; reload and try again.';end if;
 if r.kind='expense' then
  if r.status in ('Draft','Returned') and target_status='Pending' then allowed:=public.can_write_kind(r.kind);
  elsif r.status='Pending' and target_status in ('Approved','Returned') then
   if r.created_by=auth.uid() then raise exception 'Cannot approve your own request.';end if;
   allowed:=public.has_role(array['chairperson','vice_chairperson']);
  elsif r.status='Approved' and target_status='Paid' then allowed:=public.has_role(array['treasurer']);end if;
 elsif r.kind='minutes' then
  if r.status in ('Draft','Returned') and target_status='In review' then allowed:=public.can_write_kind(r.kind);
  elsif r.status='In review' and target_status in ('Approved','Returned') then
   if r.created_by=auth.uid() then raise exception 'Cannot approve your own request.';end if;
   allowed:=public.has_role(array['chairperson','vice_chairperson']);end if;
 elsif r.status not in ('Completed','Closed','Received','Fulfilled') then
  allowed:=public.can_write_kind(r.kind) and target_status<>r.status and case
   when r.kind='pledge' then target_status='Fulfilled'
   when r.kind='beneficiary' then target_status in ('Active','Closed')
   else target_status in ('Active','Completed') end;
 end if;
 if not allowed then raise exception 'Transition not permitted.';end if;
 update records set status=target_status,version=version+1,updated_at=now(),details=details || jsonb_build_object('last_action_by',auth.uid()) where id=record_id returning * into r;
 return r;
end $$;
create function public.edit_record(record_id uuid,expected_version integer,new_data jsonb) returns public.records language plpgsql security definer set search_path=public as $$
declare r public.records;
begin
 select * into r from records where id=record_id for update;
 if not found or not public.can_write_kind(r.kind) then raise exception 'Access denied.';end if;
 if r.version<>expected_version then raise exception 'Record changed; reload and try again.';end if;
 if (r.kind in ('expense','minutes') and r.status not in ('Draft','Returned')) or r.kind='donation' or r.status in ('Completed','Closed','Fulfilled') then raise exception 'Record is locked.';end if;
 if new_data->>'kind'<>r.kind then raise exception 'Access denied.';end if;
 update records set title=new_data->>'title',amount=(new_data->>'amount')::bigint,date=(new_data->>'date')::date,
 category=new_data->>'category',description=new_data->>'description',assignee=(new_data->>'assignee')::uuid,
 version=version+1,updated_at=now() where id=record_id returning * into r;
 return r;
end $$;
create table public.attachments (
 id uuid primary key default gen_random_uuid(),record_id uuid not null references public.records(id),
 path text not null unique,name text not null check(length(name)<=180),created_at timestamptz not null default now(),check(split_part(path,'/',1)=record_id::text)
);
alter table public.attachments enable row level security;
create policy attachments_read on public.attachments for select to authenticated using(exists(select 1 from records where id=record_id and public.can_read_kind(kind)));
create policy attachments_insert on public.attachments for insert to authenticated with check(exists(select 1 from records where id=record_id and public.can_write_kind(kind)));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('ahf-private','ahf-private',false,10485760,array['application/pdf','image/jpeg','image/png']);
create policy private_files_read on storage.objects for select to authenticated using(bucket_id='ahf-private' and exists(select 1 from public.records r where r.id::text=split_part(name,'/',1) and public.can_read_kind(r.kind)));
create policy private_files_insert on storage.objects for insert to authenticated with check(bucket_id='ahf-private' and exists(select 1 from public.records r where r.id::text=split_part(name,'/',1) and public.can_write_kind(r.kind)));
create policy private_files_cleanup on storage.objects for delete to authenticated using(bucket_id='ahf-private' and owner_id=auth.uid()::text and not exists(select 1 from public.attachments a where a.path=name));
create function public.claim_push_jobs() returns table(id uuid,subscription jsonb) language sql security definer set search_path=public as $$
 with ready as (
  select j.id from push_jobs j join notifications n on n.id=j.notification_id join profiles p on p.id=n.user_id
  join push_subscriptions s on s.id=j.subscription_id join records r on r.id=n.record_id
  where not j.done and j.attempts<5 and j.available_at<=now() and p.active and (
   case when r.kind='beneficiary' then p.roles && array['administrator','program_officer']
   when r.kind in ('donation','pledge','budget','expense','donor') then p.roles && array['chairperson','vice_chairperson','administrator','treasurer'] else true end
  ) order by j.available_at limit 20 for update of j skip locked
 ), claimed as (update push_jobs set attempts=attempts+1,available_at=now()+interval '2 minutes' where push_jobs.id in(select ready.id from ready) returning push_jobs.id,push_jobs.subscription_id)
 select c.id,s.subscription from claimed c join push_subscriptions s on s.id=c.subscription_id $$;
create function public.finish_push_job(job_id uuid,succeeded boolean,expired boolean) returns void language plpgsql security definer set search_path=public as $$
begin
 if expired then delete from push_subscriptions where id=(select subscription_id from push_jobs where id=job_id);
 else update push_jobs set done=succeeded,available_at=now()+interval '5 minutes' where id=job_id;end if;
end $$;
revoke all on all tables in schema public from anon,authenticated;
grant select on public.profiles,public.records,public.audit_events,public.notifications,public.push_subscriptions,public.attachments to authenticated;
grant insert on public.records,public.attachments to authenticated;
grant insert,update,delete on public.push_subscriptions to authenticated;
grant update(read_at) on public.notifications to authenticated;
revoke all on function public.transition_record(uuid,text,integer) from public;
grant execute on function public.transition_record(uuid,text,integer) to authenticated;
revoke all on function public.edit_record(uuid,integer,jsonb) from public;
grant execute on function public.edit_record(uuid,integer,jsonb) to authenticated;
revoke all on function public.claim_push_jobs(),public.finish_push_job(uuid,boolean,boolean) from public,anon,authenticated;
grant execute on function public.claim_push_jobs(),public.finish_push_job(uuid,boolean,boolean) to service_role;
revoke all on function public.guard_new_record(),public.record_event() from public,anon,authenticated;
commit;
