-- Programme areas are proposals until staff deliberately activate delivery.
begin;
create or replace function public.guard_new_record() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.status <> (case when new.kind in ('expense','minutes') then 'Draft' when new.kind='program' then 'Planned' when new.kind='donation' then 'Received' when new.kind='pledge' then 'Pledged' when new.kind='beneficiary' then 'Open' else 'Active' end)
 or new.details <> '{}'::jsonb or new.version<>1 then raise exception 'Invalid initial record.';end if;
 new.created_at=now();new.updated_at=now();return new;
end $$;
create function public.initialize_programme_areas() returns setof public.records language plpgsql security definer set search_path=public as $$
declare p record;r public.records;
begin
 if not public.can_write_kind('program') then raise exception 'Access denied.';end if;
 perform pg_advisory_xact_lock(741096,2);
 for p in select * from (values
 ('Education and child development','Learning support, educational materials and appropriate support to schools and families.'),
 ('Child protection and well-being','Safeguarding awareness, prevention and referrals to qualified services.'),
 ('Family support','Community-based support that promotes safe, nurturing family environments.'),
 ('Community development','Community-led initiatives shaped by locally identified needs.'),
 ('Health, hygiene and basic needs','Health education, hygiene and sanitation promotion within the Foundation’s capacity.'),
 ('Empowerment and skills development','Life skills, leadership, vocational training and livelihood-related initiatives.'),
 ('Partnership and fundraising','Responsible partnerships, donations and in-kind contributions.'),
 ('Monitoring and accountability','Programme monitoring, evaluation, feedback, records and reporting.')
 ) as areas(title,description) loop
  if not exists(select 1 from records where kind='program' and title=p.title) then
   insert into records(kind,title,status,date,category,description,created_by) values('program',p.title,'Planned',(now() at time zone 'Africa/Kampala')::date,p.title,p.description || E'\nSource: AHF Updated Draft Constitution, Article 7. Proposed area; active delivery is not yet confirmed.',auth.uid()) returning * into r;
   return next r;
  end if;
 end loop;
end $$;
revoke all on function public.initialize_programme_areas() from public,anon;
grant execute on function public.initialize_programme_areas() to authenticated;
commit;
