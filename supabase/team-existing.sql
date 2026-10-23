-- Run as the database owner AFTER migrations 001–004.
-- Uses only the two existing Auth UUIDs supplied by AHF. No Auth accounts are created.
begin;
insert into public.profiles(id,name,roles,active) values
 ('5f6e9131-1aca-4a3e-b6c1-6f82ada9d4fd','Sanle Esaie',array['administrator'],true),
 ('6966f874-0661-459d-81da-5badff66ebc3','Aziko Paula',array['treasurer','secretary'],true)
on conflict(id) do update set name=excluded.name;
-- Existing roles, deactivation and expiry are preserved on conflict.
-- Independently authorized reviewers are required for approvals. The governance
-- team must decide who receives finance_approver or leadership responsibilities.
-- Never grant a role merely to bypass the rule against approving one's own request.
commit;
