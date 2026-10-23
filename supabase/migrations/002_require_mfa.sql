-- Apply AFTER 001_workspace.sql. Also required when upgrading the first release.
-- Private data remains unavailable to password-only sessions, including direct
-- REST/Storage access that bypasses the application server.
begin;
create or replace function public.is_active() returns boolean
language sql stable security definer set search_path=public as $$
 select coalesce((auth.jwt()->>'aal')='aal2',false)
 and exists(select 1 from profiles where id=auth.uid() and active)
$$;
create or replace function public.has_role(wanted text[]) returns boolean
language sql stable security definer set search_path=public as $$
 select public.is_active() and exists(select 1 from profiles where id=auth.uid() and active and roles && wanted)
$$;
commit;
