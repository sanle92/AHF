-- AHF v0.3. Apply after 001–003. Additive migration; existing records and IDs remain.
begin;
alter table public.profiles add column access_until timestamptz;
do $$ declare c record;begin for c in select conname from pg_constraint where conrelid='public.profiles'::regclass and contype='c' and pg_get_constraintdef(oid) like '%roles%' loop execute format('alter table public.profiles drop constraint %I',c.conname);end loop;end $$;
alter table public.profiles add constraint profiles_roles_v3 check(roles <@ array['chairperson','vice_chairperson','administrator','secretary','treasurer','finance_manager','finance_officer','finance_approver','executive_director','operations_manager','programme_manager','program_officer','case_worker','donor_relations','fundraising_manager','monitoring_officer','volunteer_coordinator','volunteer','auditor']::text[]);
alter table public.records drop constraint records_kind_check;
alter table public.records alter column amount type numeric(18,2);
alter table public.records drop constraint records_description_check;
alter table public.records add constraint records_description_v3 check(length(description)<=20000);
alter table public.records add column currency text not null default 'UGX' check(currency in ('UGX','USD','EUR','GBP','KES'));
alter table public.records add column program_id uuid references public.records(id);
alter table public.records add column parent_id uuid references public.records(id);
alter table public.records add column collaborators uuid[] not null default '{}';
alter table public.records add constraint amount_precision check(currency<>'UGX' or amount=round(amount));
alter table public.records add constraint no_self_parent check(parent_id is distinct from id and program_id is distinct from id);
create index records_program on public.records(program_id);
create index records_parent on public.records(parent_id);
create table public.module_rules(kind text primary key,label text not null,group_name text not null,read_roles text[] not null,write_roles text[] not null,initial_status text not null,states text[] not null,fields jsonb not null);
alter table public.module_rules enable row level security;
insert into public.module_rules values
('program','Programmes','Programs',array['administrator','executive_director','operations_manager','programme_manager','program_officer','treasurer','finance_manager','finance_officer','auditor','case_worker','volunteer','donor_relations','fundraising_manager','monitoring_officer','volunteer_coordinator']::text[],array['administrator','executive_director','operations_manager','programme_manager','program_officer']::text[],'Planned',array['Planned','Approved','Active','On hold','Completed','Archived']::text[],'[{"key":"objectives","label":"Objectives","type":"textarea","required":true},{"key":"location","label":"Location","type":"text"},{"key":"start_date","label":"Start date","type":"date"},{"key":"end_date","label":"End date","type":"date"},{"key":"target_group","label":"Intended participants","type":"text"},{"key":"outcomes","label":"Expected outcomes","type":"textarea"},{"key":"milestones","label":"Milestones","type":"rows","columns":["Milestone","Target date","Success measure"]},{"key":"risks","label":"Risks and responses","type":"rows","columns":["Risk","Mitigation"]},{"key":"evidence","label":"Closure evidence / learning","type":"textarea"}]'::jsonb),
('activity','Activities','Programs',array['administrator','executive_director','operations_manager','programme_manager','program_officer','monitoring_officer','volunteer_coordinator','volunteer']::text[],array['administrator','executive_director','operations_manager','programme_manager','program_officer']::text[],'Planned',array['Planned','Scheduled','In progress','Completed','Cancelled']::text[],'[{"key":"location","label":"Location","type":"text"},{"key":"starts_at","label":"Starts at (Kampala time)","type":"datetime"},{"key":"ends_at","label":"Ends at (Kampala time)","type":"datetime"},{"key":"resources","label":"Resources needed","type":"textarea"},{"key":"attendance_count","label":"Attendance count","type":"number"},{"key":"outputs","label":"Outputs and results","type":"rows","columns":["Output","Result","Evidence"]},{"key":"evidence","label":"Completion evidence","type":"textarea"}]'::jsonb),
('beneficiary','Support cases','Beneficiaries',array['administrator','case_worker','program_officer','programme_manager']::text[],array['administrator','case_worker','program_officer','programme_manager']::text[],'Open',array['Open','Assessed','Approved','Active','Follow-up','Closed']::text[],'[{"key":"need","label":"Assessed need","type":"textarea","required":true},{"key":"support_plan","label":"Agreed support plan","type":"textarea"},{"key":"consent_reference","label":"Consent reference","type":"text"},{"key":"follow_up_date","label":"Follow-up date","type":"date"},{"key":"outcome","label":"Outcome / closure reason","type":"textarea"}]'::jsonb),
('donor','Donors','Donors',array['donor_relations','fundraising_manager','treasurer','finance_manager','finance_officer','auditor']::text[],array['donor_relations','fundraising_manager','treasurer','finance_manager']::text[],'Active',array['Active','Inactive']::text[],'[{"key":"donor_type","label":"Donor type","type":"select","options":["Individual","Organization","Church / group","Business"]},{"key":"contact_person","label":"Contact person","type":"text"},{"key":"email","label":"Email","type":"email"},{"key":"phone","label":"Telephone","type":"text"},{"key":"address","label":"Address","type":"text"},{"key":"communication","label":"Preferred communication","type":"select","options":["Email","Phone","No outreach"]},{"key":"consent","label":"Permission for outreach","type":"checkbox"},{"key":"anonymous","label":"Anonymous public recognition","type":"checkbox"},{"key":"interests","label":"Interests / programme preferences","type":"textarea"}]'::jsonb),
('donation','Donations','Donors',array['treasurer','finance_manager','finance_officer','auditor','donor_relations','fundraising_manager']::text[],array['treasurer','finance_manager','finance_officer','donor_relations','fundraising_manager']::text[],'Unverified',array['Unverified','Received','Voided']::text[],'[{"key":"donor_id","label":"Donor","type":"record","ref":["donor"],"required":true},{"key":"pledge_id","label":"Related pledge","type":"record","ref":["pledge"],"required":false},{"key":"campaign_id","label":"Campaign","type":"record","ref":["campaign"],"required":false},{"key":"account_id","label":"Receiving account","type":"record","ref":["account"],"required":false},{"key":"fund_id","label":"Designated fund","type":"record","ref":["fund"],"required":false},{"key":"method","label":"Payment method","type":"select","options":["Bank transfer","Mobile money","Cash","Cheque"],"required":true},{"key":"reference","label":"Transaction reference","type":"text"},{"key":"acknowledgment","label":"Acknowledgment","type":"select","options":["Not prepared","Prepared","Sent"]},{"key":"restrictions","label":"Donor restrictions","type":"textarea"}]'::jsonb),
('pledge','Pledges','Donors',array['treasurer','finance_manager','finance_officer','auditor','donor_relations','fundraising_manager']::text[],array['donor_relations','fundraising_manager','treasurer','finance_manager']::text[],'Pledged',array['Pledged','Partly fulfilled','Fulfilled','Cancelled']::text[],'[{"key":"donor_id","label":"Donor","type":"record","ref":["donor"],"required":true},{"key":"campaign_id","label":"Campaign","type":"record","ref":["campaign"],"required":false},{"key":"due_date","label":"Expected date","type":"date"},{"key":"restrictions","label":"Restrictions","type":"textarea"}]'::jsonb),
('campaign','Campaigns','Donors',array['treasurer','finance_manager','finance_officer','auditor','donor_relations','fundraising_manager']::text[],array['donor_relations','fundraising_manager','treasurer','finance_manager']::text[],'Draft',array['Draft','Active','Completed','Cancelled']::text[],'[{"key":"start_date","label":"Start date","type":"date"},{"key":"end_date","label":"End date","type":"date"},{"key":"audience","label":"Audience","type":"text"},{"key":"message","label":"Campaign message","type":"textarea"}]'::jsonb),
('interaction','Donor follow-ups','Donors',array['donor_relations','fundraising_manager','treasurer','finance_manager']::text[],array['donor_relations','fundraising_manager','treasurer','finance_manager']::text[],'Open',array['Open','Completed']::text[],'[{"key":"donor_id","label":"Donor","type":"record","ref":["donor"],"required":true},{"key":"channel","label":"Channel","type":"select","options":["Email","Phone","Meeting","Letter"]},{"key":"contact_date","label":"Contact date","type":"date"},{"key":"next_action","label":"Next action","type":"textarea"}]'::jsonb),
('in_kind','In-kind gifts','Donors',array['donor_relations','fundraising_manager','treasurer','finance_manager','finance_officer','auditor']::text[],array['donor_relations','fundraising_manager','treasurer','finance_manager']::text[],'Expected',array['Expected','Received','Distributed']::text[],'[{"key":"donor_id","label":"Donor","type":"record","ref":["donor"],"required":false},{"key":"items","label":"Items","type":"rows","columns":["Item","Quantity","Unit","Condition"]},{"key":"valuation_basis","label":"Valuation basis (if applicable)","type":"text"},{"key":"distribution","label":"Distribution record","type":"textarea"}]'::jsonb),
('budget','Budgets','Finance',array['treasurer','finance_manager','finance_officer','auditor','administrator','executive_director','operations_manager','programme_manager']::text[],array['treasurer','finance_manager','finance_officer']::text[],'Draft',array['Draft','Submitted','Approved','Returned','Closed']::text[],'[{"key":"fund_id","label":"Funding source","type":"record","ref":["fund"],"required":false},{"key":"budget_line","label":"Budget line","type":"text"},{"key":"start_date","label":"Period starts","type":"date","required":true},{"key":"end_date","label":"Period ends","type":"date","required":true},{"key":"justification","label":"Budget justification","type":"textarea"}]'::jsonb),
('expense','Expense requests','Finance',array['treasurer','finance_manager','finance_officer','auditor','administrator','executive_director','operations_manager','programme_manager']::text[],array['treasurer','finance_manager','finance_officer','administrator','executive_director','operations_manager','programme_manager']::text[],'Draft',array['Draft','Submitted','Approved','Returned','Partly paid','Paid','Reconciled','Cancelled']::text[],'[{"key":"budget_id","label":"Approved budget","type":"record","ref":["budget"],"required":true},{"key":"fund_id","label":"Funding source","type":"record","ref":["fund"],"required":false},{"key":"payee","label":"Payee / supplier","type":"text","required":true},{"key":"purpose","label":"Purpose","type":"textarea","required":true},{"key":"quotation_reference","label":"Quotation reference","type":"text"},{"key":"approval_note","label":"Reviewer note","type":"textarea"}]'::jsonb),
('payment','Payments','Finance',array['treasurer','finance_manager','finance_officer','auditor']::text[],array['treasurer','finance_manager','finance_officer']::text[],'Draft',array['Draft','Paid','Reconciled','Voided']::text[],'[{"key":"expense_id","label":"Approved expense request","type":"record","ref":["expense"],"required":true},{"key":"account_id","label":"Paying account","type":"record","ref":["account"],"required":true},{"key":"method","label":"Payment method","type":"select","options":["Bank transfer","Mobile money","Cash","Cheque"],"required":true},{"key":"reference","label":"Payment reference","type":"text","required":true},{"key":"evidence","label":"Payment evidence / receipt reference","type":"textarea","required":true}]'::jsonb),
('account','Accounts','Finance',array['treasurer','finance_manager','finance_officer','auditor']::text[],array['treasurer','finance_manager']::text[],'Draft',array['Draft','Active','Closed']::text[],'[{"key":"account_type","label":"Account type","type":"select","options":["Bank","Mobile money","Cash"],"required":true},{"key":"account_reference","label":"Account reference (masked)","type":"text"},{"key":"opening_evidence","label":"Opening balance evidence","type":"textarea","required":true}]'::jsonb),
('fund','Funds','Finance',array['treasurer','finance_manager','finance_officer','auditor']::text[],array['treasurer','finance_manager']::text[],'Active',array['Active','Closed']::text[],'[{"key":"restriction_type","label":"Fund type","type":"select","options":["Unrestricted","Restricted"],"required":true},{"key":"purpose","label":"Permitted purpose","type":"textarea","required":true},{"key":"report_due","label":"Reporting deadline","type":"date"}]'::jsonb),
('transfer','Transfers','Finance',array['treasurer','finance_manager','finance_officer','auditor']::text[],array['treasurer','finance_manager','finance_officer']::text[],'Draft',array['Draft','Submitted','Approved','Returned','Posted','Voided']::text[],'[{"key":"from_account_id","label":"From account","type":"record","ref":["account"],"required":true},{"key":"to_account_id","label":"To account","type":"record","ref":["account"],"required":true},{"key":"reference","label":"Transfer reference","type":"text","required":true},{"key":"reason","label":"Reason","type":"textarea"}]'::jsonb),
('advance','Cash advances','Finance',array['treasurer','finance_manager','finance_officer','auditor']::text[],array['treasurer','finance_manager','finance_officer']::text[],'Draft',array['Draft','Submitted','Approved','Returned','Paid','Settled','Voided']::text[],'[{"key":"account_id","label":"Paying account","type":"record","ref":["account"],"required":true},{"key":"budget_id","label":"Approved budget","type":"record","ref":["budget"],"required":true},{"key":"purpose","label":"Purpose","type":"textarea","required":true},{"key":"accountable_person","label":"Accountable staff member","type":"people","required":true},{"key":"retirement_due","label":"Accountability due","type":"date","required":true},{"key":"reference","label":"Payment reference","type":"text"}]'::jsonb),
('retirement','Advance accountability','Finance',array['treasurer','finance_manager','finance_officer','auditor']::text[],array['treasurer','finance_manager','finance_officer']::text[],'Draft',array['Draft','Submitted','Approved','Returned']::text[],'[{"key":"advance_id","label":"Paid advance","type":"record","ref":["advance"],"required":true},{"key":"returned","label":"Cash returned","type":"number","required":true},{"key":"evidence","label":"Receipt references and explanation","type":"textarea","required":true},{"key":"items","label":"Expenditure breakdown","type":"rows","columns":["Item","Amount","Receipt reference"]}]'::jsonb),
('reconciliation','Reconciliations','Finance',array['treasurer','finance_manager','finance_officer','auditor']::text[],array['treasurer','finance_manager','finance_officer']::text[],'Draft',array['Draft','Submitted','Approved','Returned']::text[],'[{"key":"account_id","label":"Account","type":"record","ref":["account"],"required":true},{"key":"statement_balance","label":"Statement / cash-count balance","type":"number","required":true},{"key":"statement_reference","label":"Statement reference","type":"text","required":true},{"key":"explanation","label":"Difference / outstanding items","type":"textarea"},{"key":"start_date","label":"Statement starts","type":"date","required":true},{"key":"end_date","label":"Statement ends","type":"date","required":true}]'::jsonb),
('period','Financial periods','Finance',array['treasurer','finance_manager','finance_officer','auditor']::text[],array['treasurer','finance_manager']::text[],'Open',array['Open','Closed']::text[],'[{"key":"start_date","label":"Period starts","type":"date","required":true},{"key":"end_date","label":"Period ends","type":"date","required":true},{"key":"evidence","label":"Close review / reconciliation evidence","type":"textarea"}]'::jsonb),
('meeting','Meetings','Secretary',array['secretary','administrator']::text[],array['secretary','administrator']::text[],'Draft',array['Draft','Scheduled','Held','Cancelled']::text[],'[{"key":"reference","label":"Meeting reference","type":"text","required":true},{"key":"meeting_type","label":"Meeting type","type":"select","options":["Leadership","General meeting","Annual general meeting","Programme","Special"],"required":true},{"key":"starts_at","label":"Starts at (Kampala time)","type":"datetime","required":true},{"key":"ends_at","label":"Ends at (Kampala time)","type":"datetime","required":true},{"key":"location","label":"Venue","type":"text"},{"key":"join_url","label":"Online meeting URL","type":"text"},{"key":"chair_id","label":"Chair","type":"people"},{"key":"minute_taker_id","label":"Minute-taker","type":"people"},{"key":"attendees","label":"Attendees","type":"people"},{"key":"agenda","label":"Agenda","type":"rows","columns":["Topic","Presenter","Minutes"]},{"key":"attendance","label":"Attendance","type":"rows","columns":["Name","Present / apology / absent"]},{"key":"reminder_minutes","label":"Reminder before meeting (minutes)","type":"number"},{"key":"recurrence","label":"Repeat","type":"select","options":["None","Weekly","Monthly"]}]'::jsonb),
('minutes','Minutes','Secretary',array['secretary','administrator']::text[],array['secretary','administrator']::text[],'Draft',array['Draft','In review','Approved','Returned']::text[],'[{"key":"meeting_id","label":"Meeting","type":"record","ref":["meeting"],"required":true},{"key":"reference","label":"Minutes reference","type":"text","required":true},{"key":"attendance","label":"Attendance and apologies","type":"rows","columns":["Name","Attendance / apology"]},{"key":"discussions","label":"Discussion by agenda item","type":"rows","columns":["Agenda item","Discussion","Decision"]},{"key":"votes","label":"Votes / conflicts of interest","type":"rows","columns":["Item","Vote / conflict","Action taken"]},{"key":"actions","label":"Agreed actions","type":"rows","columns":["Action","Responsible person","Deadline"]},{"key":"approver_id","label":"Submit to","type":"people","required":true},{"key":"amendment_of","label":"Amends approved minutes","type":"record","ref":["minutes"]}]'::jsonb),
('resolution','Resolutions','Secretary',array['secretary','administrator']::text[],array['secretary','administrator']::text[],'Proposed',array['Proposed','Adopted','In progress','Implemented','Verified','Cancelled']::text[],'[{"key":"meeting_id","label":"Originating meeting","type":"record","ref":["meeting"],"required":true},{"key":"reference","label":"Resolution number","type":"text","required":true},{"key":"decision","label":"Decision text","type":"textarea","required":true},{"key":"implementation","label":"Implementation steps","type":"rows","columns":["Step","Owner","Due date"]},{"key":"evidence","label":"Implementation evidence","type":"textarea"},{"key":"verification","label":"Verification note","type":"textarea"}]'::jsonb),
('correspondence','Correspondence','Secretary',array['secretary','administrator']::text[],array['secretary','administrator']::text[],'Draft',array['Draft','In review','Approved','Sent','Received','Awaiting response','Closed']::text[],'[{"key":"reference","label":"Reference number","type":"text","required":true},{"key":"direction","label":"Direction","type":"select","options":["Incoming","Outgoing"],"required":true},{"key":"sender","label":"Sender","type":"text","required":true},{"key":"recipient","label":"Recipient","type":"text","required":true},{"key":"channel","label":"Channel","type":"select","options":["Email","Letter","Phone","Meeting"],"required":true},{"key":"confidentiality","label":"Classification","type":"select","options":["Internal","Confidential"],"required":true},{"key":"response_due","label":"Response deadline","type":"date"},{"key":"reply_to","label":"Reply to","type":"record","ref":["correspondence"],"required":false},{"key":"approver_id","label":"Reviewer / signatory","type":"people"},{"key":"sent_reference","label":"Evidence of sending / delivery","type":"text"},{"key":"response","label":"Response / follow-up","type":"textarea"}]'::jsonb),
('member','Membership register','Secretary',array['secretary','administrator']::text[],array['secretary','administrator']::text[],'Active',array['Active','Resigned','Suspended']::text[],'[{"key":"reference","label":"Membership reference","type":"text","required":true},{"key":"membership_type","label":"Membership category","type":"text"},{"key":"joined","label":"Date admitted","type":"date"},{"key":"email","label":"Email","type":"email"},{"key":"phone","label":"Telephone","type":"text"},{"key":"notes","label":"Membership notes","type":"textarea"}]'::jsonb),
('task','Tasks','Tasks',array['chairperson','vice_chairperson','administrator','secretary','treasurer','finance_manager','finance_officer','finance_approver','executive_director','operations_manager','programme_manager','program_officer','case_worker','donor_relations','fundraising_manager','monitoring_officer','volunteer_coordinator','volunteer','auditor']::text[],array['chairperson','vice_chairperson','administrator','secretary','treasurer','finance_manager','finance_officer','finance_approver','executive_director','operations_manager','programme_manager','program_officer','case_worker','donor_relations','fundraising_manager','monitoring_officer','volunteer_coordinator','volunteer','auditor']::text[],'To do',array['To do','In progress','Blocked','In review','Completed','Cancelled']::text[],'[{"key":"priority","label":"Priority","type":"select","options":["Low","Normal","High","Urgent"],"required":true},{"key":"start_date","label":"Start date","type":"date"},{"key":"checklist","label":"Checklist / subtasks","type":"rows","columns":["Item","Done (yes/no)"]},{"key":"dependencies","label":"Depends on tasks","type":"record","ref":["task"]},{"key":"blocked_reason","label":"Blocker / assistance needed","type":"textarea"},{"key":"evidence","label":"Completion evidence","type":"textarea"},{"key":"reviewer_id","label":"Reviewer","type":"people"},{"key":"recurrence","label":"Repeat after completion","type":"select","options":["None","Weekly","Monthly"]},{"key":"reminder_minutes","label":"Reminder before deadline (minutes)","type":"number"}]'::jsonb),
('document','Documents','Documents',array['chairperson','vice_chairperson','administrator','secretary','treasurer','finance_manager','finance_officer','finance_approver','executive_director','operations_manager','programme_manager','program_officer','case_worker','donor_relations','fundraising_manager','monitoring_officer','volunteer_coordinator','volunteer','auditor']::text[],array['administrator','executive_director','operations_manager','secretary','programme_manager']::text[],'Draft',array['Draft','Approved','Archived']::text[],'[{"key":"reference","label":"Document reference","type":"text"},{"key":"classification","label":"Classification","type":"select","options":["Internal","Confidential"],"required":true},{"key":"review_date","label":"Review date","type":"date"},{"key":"version_label","label":"Document version","type":"text"}]'::jsonb),
('indicator','Indicators','Programs',array['administrator','executive_director','operations_manager','programme_manager','program_officer','monitoring_officer']::text[],array['administrator','executive_director','operations_manager','programme_manager','program_officer','monitoring_officer']::text[],'Active',array['Active','Completed']::text[],'[{"key":"unit","label":"Unit of measure","type":"select","options":["People","Households","Activities","Items","Percent","Other"],"required":true},{"key":"baseline","label":"Baseline","type":"number","required":true},{"key":"target","label":"Target","type":"number","required":true},{"key":"actual","label":"Actual result","type":"number","required":true},{"key":"reported_on","label":"Reporting date","type":"date","required":true},{"key":"method","label":"Measurement method / evidence","type":"textarea","required":true},{"key":"counting","label":"Counting rule","type":"select","options":["Unique individuals","Unique households","Repeat contacts","Activities / outputs","Other"],"required":true}]'::jsonb);
alter table public.records add constraint record_kind_fk foreign key(kind) references public.module_rules(kind);
create table public.program_members(program_id uuid not null references public.records(id),user_id uuid not null references public.profiles(id),primary key(program_id,user_id));
alter table public.program_members enable row level security;
create or replace function public.is_active() returns boolean language sql stable security definer set search_path=public as $$select coalesce(auth.jwt()->>'aal'='aal2',false) and exists(select 1 from profiles where id=auth.uid() and active and (access_until is null or access_until>now()))$$;
create or replace function public.has_role(wanted text[]) returns boolean language sql stable security definer set search_path=public as $$select public.is_active() and exists(select 1 from profiles where id=auth.uid() and roles&&wanted)$$;
create or replace function public.can_read_kind(k text) returns boolean language sql stable security definer set search_path=public as $$select public.is_active() and exists(select 1 from module_rules m join profiles p on p.id=auth.uid() where m.kind=k and p.roles&&m.read_roles)$$;
create or replace function public.can_write_kind(k text) returns boolean language sql stable security definer set search_path=public as $$select public.is_active() and exists(select 1 from module_rules m join profiles p on p.id=auth.uid() where m.kind=k and p.roles&&m.write_roles)$$;
create function public.in_program(pid uuid,uid uuid default auth.uid()) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from program_members where program_id=pid and user_id=uid)$$;
create function public.can_access_record(rid uuid) returns boolean language plpgsql stable security definer set search_path=public as $$
declare r records;own boolean;member boolean;
begin
 select * into r from records where id=rid;if not found or not can_read_kind(r.kind) then return false;end if;
 own:=r.created_by=auth.uid() or r.assignee=auth.uid() or auth.uid()=any(r.collaborators);
 member:=in_program(r.program_id) or (r.kind='program' and in_program(r.id));
 if r.kind in ('meeting','minutes','resolution','correspondence','member') then return has_role(array['secretary','administrator']);end if;
 if r.kind='beneficiary' then return own or member;end if;
 if r.kind='task' and r.details->>'reviewer_id'=auth.uid()::text then return true;end if;
 if r.kind='program' and has_role(array['treasurer','finance_manager','finance_officer','auditor']) then return true;end if;
 if r.kind in ('task','document','program','activity','indicator') then return own or member or has_role(array['administrator','executive_director','operations_manager']);end if;
 if r.kind in ('expense','budget') then return own or (r.kind='budget' and member) or has_role(array['treasurer','finance_manager','finance_officer','auditor']);end if;
 return true;
end $$;
create function public.can_edit_record(rid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from records r where r.id=rid and can_access_record(r.id) and can_write_kind(r.kind) and r.status not in ('Submitted','In review','Approved','Paid','Partly paid','Reconciled','Posted','Received','Settled','Voided','Closed','Completed','Archived','Fulfilled','Distributed'))$$;
drop policy records_read on public.records;
drop policy records_insert on public.records;
create policy record_scoped_read on public.records for select to authenticated using(public.can_access_record(id));
revoke insert on public.records from authenticated;
create policy membership_read on public.program_members for select to authenticated using(public.is_active() and (user_id=auth.uid() or public.can_access_record(program_id)));
create function public.set_program_member(pid uuid,uid uuid,enabled boolean) returns void language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from records where id=pid and kind='program') or not is_active() or not (has_role(array['administrator','executive_director','operations_manager']) or (has_role(array['programme_manager']) and exists(select 1 from records where id=pid and created_by=auth.uid()))) then raise exception 'Access denied.';end if;
 if not exists(select 1 from profiles where id=uid and active) then raise exception 'Choose an active team member.';end if;
 if enabled then insert into program_members values(pid,uid) on conflict do nothing;else delete from program_members where program_id=pid and user_id=uid;end if;
 insert into audit_events(record_id,actor_id,action,new_data) values(pid,auth.uid(),case when enabled then 'Programme access granted' else 'Programme access revoked' end,jsonb_build_object('user_id',uid));
end $$;
-- Existing generic statuses are preserved in metadata while being upgraded.
alter table public.records disable trigger record_event;
update public.records set details=details||jsonb_build_object('legacy_status',status),status=case when kind='expense' and status='Pending' then 'Submitted' when kind='task' and status='Active' then 'To do' when kind='meeting' and status='Active' then 'Draft' when kind='resolution' and status='Active' then 'Proposed' when kind='correspondence' and status='Active' then 'Draft' else status end where (kind='expense' and status='Pending') or (kind in ('task','meeting','resolution','correspondence') and status='Active');
update public.records set details=details||'{"legacy_unposted":true}'::jsonb where kind in ('donation','expense') and status in ('Received','Paid','Reconciled');
alter table public.records enable trigger record_event;
create table public.approval_requests(id uuid primary key default gen_random_uuid(),record_id uuid not null references records(id),record_kind text not null,title text not null,summary text not null,amount numeric(18,2) not null,currency text not null,requested_by uuid not null references profiles(id),assigned_to uuid references profiles(id),status text not null default 'Pending' check(status in ('Pending','Approved','Returned')),record_version integer not null,snapshot jsonb not null,decision_note text,decided_by uuid references profiles(id),created_at timestamptz not null default now(),decided_at timestamptz);
create unique index one_pending_approval on public.approval_requests(record_id) where status='Pending';
alter table public.approval_requests enable row level security;
create table public.organization_settings(key text primary key,value jsonb not null);
insert into public.organization_settings values('approval_limits','{"UGX":500000,"USD":200,"EUR":200,"GBP":150,"KES":20000}');
alter table public.organization_settings enable row level security;
create function public.may_decide(a public.approval_requests) returns boolean language sql stable security definer set search_path=public as $$
 select is_active() and a.requested_by<>auth.uid() and (a.assigned_to is null or a.assigned_to=auth.uid()) and
 case when a.record_kind='minutes' then has_role(array['chairperson','vice_chairperson'])
 when a.amount>coalesce((select (value->>a.currency)::numeric from organization_settings where key='approval_limits'),0) then has_role(array['chairperson','vice_chairperson'])
 else has_role(array['chairperson','vice_chairperson','treasurer','finance_manager','finance_approver']) end $$;
create policy approval_read on public.approval_requests for select to authenticated using(public.is_active() and (public.may_decide(approval_requests) or requested_by=auth.uid()));
create table public.record_comments(id uuid primary key default gen_random_uuid(),record_id uuid not null references records(id),author_id uuid not null references profiles(id),body text not null check(length(body) between 1 and 5000),created_at timestamptz not null default now());
alter table public.record_comments enable row level security;
create policy comments_read on public.record_comments for select to authenticated using(public.can_access_record(record_id));
create policy comments_insert on public.record_comments for insert to authenticated with check(public.can_access_record(record_id) and author_id=auth.uid());
create table public.ledger_entries(id uuid primary key default gen_random_uuid(),record_id uuid not null references records(id),account_id uuid not null references records(id),fund_id uuid references records(id),amount numeric(18,2) not null,currency text not null,posting_date date not null,actor_id uuid references profiles(id),reversal_of uuid unique references ledger_entries(id),created_at timestamptz not null default now());
create index ledger_account on public.ledger_entries(account_id,posting_date);
alter table public.ledger_entries enable row level security;
create policy ledger_read on public.ledger_entries for select to authenticated using(public.has_role(array['treasurer','finance_manager','finance_officer','auditor']) and public.can_access_record(account_id));
create function public.validate_details(k text,data jsonb,required_fields boolean default false) returns void language plpgsql stable security definer set search_path=public as $$
declare spec jsonb;f jsonb;v jsonb;key text;linked records;pid uuid;
begin
 if jsonb_typeof(data)<>'object' or length(data::text)>100000 then raise exception 'Invalid form details.';end if;
 select fields into spec from module_rules where kind=k;
 for key in select jsonb_object_keys(data) loop if not exists(select 1 from jsonb_array_elements(spec) s where s->>'key'=key) then raise exception 'Unknown form field.';end if;end loop;
 for f in select * from jsonb_array_elements(spec) loop
  v:=data->(f->>'key');
  if v is null or v='null'::jsonb or v='""'::jsonb then if required_fields and coalesce((f->>'required')::boolean,false) then raise exception 'Complete all required form fields.';end if;continue;end if;
  if f->>'type'='number' and (jsonb_typeof(v)<>'number' or abs((v#>>'{}')::numeric)>1000000000000) then raise exception 'Invalid numeric field.';end if;
  if f->>'type'='checkbox' and jsonb_typeof(v)<>'boolean' then raise exception 'Invalid checkbox.';end if;
  if f->>'type'='rows' and (jsonb_typeof(v)<>'array' or jsonb_array_length(v)>50) then raise exception 'Invalid table rows.';end if;
  if f->>'type'='rows' then if exists(select 1 from jsonb_array_elements(v) row where jsonb_typeof(row)<>'array' or jsonb_array_length(row)<>jsonb_array_length(f->'columns')) then raise exception 'Invalid table columns.';end if;end if;
  if f->>'type'='rows' and exists(select 1 from jsonb_array_elements(v) rw,jsonb_array_elements(rw) cell where jsonb_typeof(cell)<>'string' or length(cell#>>'{}')>2000) then raise exception 'Invalid table cell.';end if;
  if f->>'key'='reminder_minutes' and ((v#>>'{}')::numeric<0 or (v#>>'{}')::numeric>43200 or (v#>>'{}')::numeric<>trunc((v#>>'{}')::numeric)) then raise exception 'Reminder must be a whole number from zero to 43200.';end if;
  if f->>'type' in ('text','textarea','select','date','datetime','email') then
   if jsonb_typeof(v)<>'string' or length(v#>>'{}')>10000 then raise exception 'Invalid text field.';end if;
   if f ? 'options' and not (f->'options' @> jsonb_build_array(v)) then raise exception 'Invalid selection.';end if;
   if f->>'type'='date' then perform (v#>>'{}')::date;end if;
   if f->>'type'='datetime' then perform (v#>>'{}')::timestamptz;end if;
  end if;
  if f->>'type'='record' then
   pid:=(v#>>'{}')::uuid;select * into linked from records where id=pid;
   if not found or not can_access_record(pid) or not (f->'ref' @> jsonb_build_array(linked.kind)) then raise exception 'Linked record is not accessible.';end if;
  end if;
  if f->>'type'='people' then
   if jsonb_typeof(v)='array' then if exists(select 1 from jsonb_array_elements_text(v) x where not exists(select 1 from profiles where id=x::uuid and active)) then raise exception 'Choose active team members.';end if;
   elsif not exists(select 1 from profiles where id=(v#>>'{}')::uuid and active) then raise exception 'Choose an active team member.';end if;
  end if;
 end loop;
end $$;
create function public.validate_links(r public.records) returns void language plpgsql stable security definer set search_path=public as $$
begin
 if r.program_id is not null and not exists(select 1 from records where id=r.program_id and kind='program' and can_access_record(id)) and not (r.kind='task' and exists(select 1 from records where id=r.parent_id and kind='task' and program_id=r.program_id and can_access_record(id))) then raise exception 'Programme is not accessible.';end if;
 if r.parent_id is not null and not can_access_record(r.parent_id) then raise exception 'Source record is not accessible.';end if;
 if r.assignee is not null and not exists(select 1 from profiles where id=r.assignee and active) then raise exception 'Choose an active assignee.';end if;
 if cardinality(r.collaborators)>30 or exists(select 1 from unnest(r.collaborators) x where not exists(select 1 from profiles where id=x and active)) then raise exception 'Choose active collaborators.';end if;
 if r.kind='task' and r.created_by=auth.uid() and not exists(select 1 from records where id=r.id) and not has_role(array['administrator','executive_director','operations_manager','programme_manager','volunteer_coordinator','secretary']) and (r.assignee is distinct from auth.uid() or cardinality(r.collaborators)>0) then raise exception 'You may create tasks only for yourself.';end if;
 if r.kind in ('activity','indicator','beneficiary') and r.program_id is null then raise exception 'Choose a programme.';end if;
 if r.kind='task' and r.details->>'dependencies'=r.id::text then raise exception 'A task cannot depend on itself.';end if;
end $$;
create or replace function public.guard_new_record() returns trigger language plpgsql security definer set search_path=public as $$
declare expected text;
begin
 select initial_status into expected from module_rules where kind=new.kind;
 if expected is null or new.status<>expected or new.version<>1 then raise exception 'Invalid initial record.';end if;
 if not can_write_kind(new.kind) then raise exception 'Access denied.';end if;
 perform validate_details(new.kind,new.details,false);perform validate_links(new);
 new.created_at=now();new.updated_at=now();return new;
end $$;
create function public.create_record_v3(payload jsonb) returns public.records language plpgsql security definer set search_path=public as $$
declare r records;k text:=payload->>'kind';
begin
 if not can_write_kind(k) then raise exception 'Access denied.';end if;
 insert into records(kind,title,status,amount,currency,date,category,description,assignee,program_id,parent_id,collaborators,details,created_by)
 values(k,btrim(payload->>'title'),(select initial_status from module_rules where kind=k),coalesce((payload->>'amount')::numeric,0),coalesce(payload->>'currency','UGX'),(payload->>'date')::date,payload->>'category',coalesce(payload->>'description',''),(payload->>'assignee')::uuid,(payload->>'program_id')::uuid,(payload->>'parent_id')::uuid,array(select jsonb_array_elements_text(coalesce(payload->'collaborators','[]')))::uuid[],coalesce(payload->'details','{}'),auth.uid()) returning * into r;
 return r;
end $$;
create or replace function public.edit_record(record_id uuid,expected_version integer,new_data jsonb) returns public.records language plpgsql security definer set search_path=public as $$
declare r records;d jsonb;
begin
 select * into r from records where id=record_id for update;
 if not found or not can_access_record(r.id) or not can_write_kind(r.kind) then raise exception 'Access denied.';end if;
 if r.version<>expected_version then raise exception 'Record changed; reload and try again.';end if;
 if not can_edit_record(r.id) or new_data->>'kind'<>r.kind then raise exception 'Record is locked.';end if;
 d:=coalesce(new_data->'details','{}');perform validate_details(r.kind,d,false);
 if r.kind='task' and not has_role(array['administrator','executive_director','operations_manager','programme_manager','volunteer_coordinator','secretary']) and ((new_data->>'assignee')::uuid is distinct from r.assignee or array(select jsonb_array_elements_text(coalesce(new_data->'collaborators','[]')))::uuid[] is distinct from r.collaborators) then raise exception 'Only a task manager can change assignments.';end if;
 r.program_id:=(new_data->>'program_id')::uuid;r.parent_id:=(new_data->>'parent_id')::uuid;r.assignee:=(new_data->>'assignee')::uuid;r.collaborators:=array(select jsonb_array_elements_text(coalesce(new_data->'collaborators','[]')))::uuid[];r.details:=d;perform validate_links(r);
 update records set title=btrim(new_data->>'title'),amount=(new_data->>'amount')::numeric,currency=coalesce(new_data->>'currency','UGX'),date=(new_data->>'date')::date,category=new_data->>'category',description=new_data->>'description',assignee=r.assignee,program_id=r.program_id,parent_id=r.parent_id,collaborators=r.collaborators,details=d,version=version+1,updated_at=now() where id=record_id returning * into r;return r;
end $$;
-- Record-scoped file access, including direct Storage API calls.
drop policy attachments_read on public.attachments;drop policy attachments_insert on public.attachments;
create policy attachments_read on public.attachments for select to authenticated using(public.can_access_record(record_id));
create policy attachments_insert on public.attachments for insert to authenticated with check(public.can_access_record(record_id) and public.can_write_kind((select kind from public.records where id=record_id)));
drop policy private_files_read on storage.objects;drop policy private_files_insert on storage.objects;
create policy private_files_read on storage.objects for select to authenticated using(bucket_id='ahf-private' and public.can_access_record(split_part(name,'/',1)::uuid));
create policy private_files_insert on storage.objects for insert to authenticated with check(bucket_id='ahf-private' and public.can_access_record(split_part(name,'/',1)::uuid) and public.can_write_kind((select kind from public.records where id=split_part(name,'/',1)::uuid)));
drop policy audit_read on public.audit_events;
create policy audit_read on public.audit_events for select to authenticated using(public.can_access_record(record_id) and public.has_role(array['administrator','executive_director','secretary','treasurer','finance_manager','auditor']));
create function public.form_details(k text,d jsonb) returns jsonb language sql stable security definer set search_path=public as $$select coalesce(jsonb_object_agg(e.key,e.value),'{}'::jsonb) from jsonb_each(d) e where exists(select 1 from module_rules m,jsonb_array_elements(m.fields) f where m.kind=k and f->>'key'=e.key)$$;
create function public.assert_open_period(d date,c text) returns void language plpgsql security definer set search_path=public as $$begin
 perform pg_advisory_xact_lock(hashtext('ahf-period-'||c));
 if d>(now() at time zone 'Africa/Kampala')::date then raise exception 'A financial posting cannot be future dated.';end if;
 if exists(select 1 from records where kind='period' and status='Closed' and currency=c and d between (details->>'start_date')::date and (details->>'end_date')::date) then raise exception 'This financial period is closed.';end if;
end $$;
create function public.post_entry(r public.records,aid uuid,value numeric,fid uuid default null,posted_on date default null) returns void language plpgsql security definer set search_path=public as $$
declare a records;f records;b numeric;
begin
 perform assert_open_period(coalesce(posted_on,r.date),r.currency);
 select * into a from records where id=aid and kind='account' for update;
 if not found or (a.status<>'Active' and not (a.id=r.id and r.kind='account' and a.status='Draft')) or a.currency<>r.currency then raise exception 'Choose an active account in the same currency.';end if;
 if value<0 and coalesce((select sum(amount) from ledger_entries where account_id=aid and currency=r.currency),0)+value<0 then raise exception 'Insufficient recorded account balance.';end if;
 if fid is not null then
  select * into f from records where id=fid and kind='fund' for update;
  if not found or f.status<>'Active' or f.currency<>r.currency then raise exception 'Choose an active fund in the same currency.';end if;
  if f.details->>'restriction_type'='Restricted' and f.program_id is not null and f.program_id is distinct from r.program_id then raise exception 'Restricted fund does not permit this programme.';end if;
  if value<0 and coalesce((select sum(amount) from ledger_entries where fund_id=fid and currency=r.currency),0)+value<0 then raise exception 'Insufficient recorded fund balance.';end if;
 end if;
 insert into ledger_entries(record_id,account_id,fund_id,amount,currency,posting_date,actor_id) values(r.id,aid,fid,value,r.currency,coalesce(posted_on,r.date),auth.uid());
end $$;
create function public.set_record_state(rid uuid,s text,extra jsonb default '{}') returns public.records language plpgsql security definer set search_path=public as $$declare r records;begin update records set status=s,details=details||extra,version=version+1,updated_at=now() where id=rid returning * into r;return r;end $$;
create function public.assert_budget(r public.records) returns void language plpgsql security definer set search_path=public as $$
declare b records;committed numeric;
begin
 select * into b from records where id=(r.details->>'budget_id')::uuid and kind='budget' for update;
 if not found or b.status<>'Approved' or b.currency<>r.currency or b.program_id is distinct from r.program_id then raise exception 'Choose an approved budget for this programme and currency.';end if;
 if r.date not between (b.details->>'start_date')::date and (b.details->>'end_date')::date then raise exception 'Expense date falls outside the budget period.';end if;
 if coalesce(b.details->>'fund_id','')<>coalesce(r.details->>'fund_id',b.details->>'fund_id','') then raise exception 'Expense funding source must match its budget.';end if;
 select coalesce(sum(amount),0) into committed from records where kind in ('expense','advance') and id<>r.id and details->>'budget_id'=b.id::text and status in ('Approved','Partly paid','Paid','Reconciled','Settled');
 if committed+r.amount>b.amount then raise exception 'This request exceeds the available approved budget.';end if;
end $$;
create function public.perform_financial_action(r public.records,target text,note text default '') returns void language plpgsql security definer set search_path=public as $$
declare source records;b records;amount_paid numeric;fid uuid;row ledger_entries;reversed numeric;
begin
 if target='Voided' then
  if not has_role(array['treasurer','finance_manager']) or length(btrim(note))<5 then raise exception 'A finance manager and a correction reason are required.';end if;
  if not exists(select 1 from ledger_entries where record_id=r.id) then raise exception 'This legacy entry needs reconciliation before correction.';end if;
  perform assert_open_period((now() at time zone 'Africa/Kampala')::date,r.currency);
  perform 1 from records where id in(select account_id from ledger_entries where record_id=r.id) order by id for update;
  for row in select * from ledger_entries where record_id=r.id and reversal_of is null order by amount desc loop
   if exists(select 1 from ledger_entries where reversal_of=row.id) then raise exception 'This transaction was already reversed.';end if;
   if row.amount>0 and coalesce((select sum(amount) from ledger_entries where account_id=row.account_id),0)<row.amount then raise exception 'Insufficient balance to reverse this receipt.';end if;
   if row.fund_id is not null then perform 1 from records where id=row.fund_id for update;if row.amount>0 and coalesce((select sum(amount) from ledger_entries where fund_id=row.fund_id),0)<row.amount then raise exception 'Insufficient fund balance to reverse this receipt.';end if;end if;
   insert into ledger_entries(record_id,account_id,fund_id,amount,currency,posting_date,actor_id,reversal_of) values(r.id,row.account_id,row.fund_id,-row.amount,row.currency,(now() at time zone 'Africa/Kampala')::date,auth.uid(),row.id);
  end loop;
  if r.kind='payment' then
   select * into source from records where id=(r.details->>'expense_id')::uuid for update;
   select coalesce(sum(amount),0) into amount_paid from records where kind='payment' and id<>r.id and status in ('Paid','Reconciled') and details->>'expense_id'=source.id::text;
   perform set_record_state(source.id,case when amount_paid=0 then 'Approved' when amount_paid<source.amount then 'Partly paid' else 'Paid' end);
  elsif r.kind='donation' and r.details->>'pledge_id' is not null then
   select * into source from records where id=(r.details->>'pledge_id')::uuid for update;
   select coalesce(sum(amount),0) into amount_paid from records where kind='donation' and id<>r.id and status='Received' and details->>'pledge_id'=source.id::text;
   perform set_record_state(source.id,case when source.status='Cancelled' then 'Cancelled' when amount_paid=0 then 'Pledged' when amount_paid<source.amount then 'Partly fulfilled' else 'Fulfilled' end);
  end if;
  return;
 end if;
 if r.amount<=0 and r.kind not in ('account','reconciliation','period') then raise exception 'Enter a positive financial amount.';end if;
 if r.kind='account' and target='Active' then
  perform assert_open_period(r.date,r.currency);
  -- Opening balances are explicit and retain their evidence; no inferred balance.
  if r.amount>0 then perform post_entry(r,r.id,r.amount);end if;
 elsif r.kind='donation' and target='Received' then
  if not has_role(array['treasurer','finance_manager','finance_officer']) then raise exception 'Access denied.';end if;
  if r.details->>'account_id' is null then raise exception 'Choose a receiving account before verification.';end if;
  if r.details->>'pledge_id' is not null then
   select * into source from records where id=(r.details->>'pledge_id')::uuid and kind='pledge' for update;
   select coalesce(sum(amount),0) into amount_paid from records where kind='donation' and status='Received' and details->>'pledge_id'=source.id::text;
   if source.status in ('Cancelled','Fulfilled') or source.currency<>r.currency or source.details->>'donor_id' is distinct from r.details->>'donor_id' or amount_paid+r.amount>source.amount then raise exception 'Donation does not match the outstanding pledge.';end if;
   perform set_record_state(source.id,case when amount_paid+r.amount=source.amount then 'Fulfilled' else 'Partly fulfilled' end);
  end if;
  perform post_entry(r,(r.details->>'account_id')::uuid,r.amount,(r.details->>'fund_id')::uuid);
 elsif r.kind='payment' and target='Paid' then
  select * into source from records where id=(r.details->>'expense_id')::uuid and kind='expense' for update;
  if not found or source.status not in ('Approved','Partly paid') or source.currency<>r.currency or source.program_id is distinct from r.program_id then raise exception 'Payment must match an approved expense request.';end if;
  select * into b from records where id=(source.details->>'budget_id')::uuid for update;
  select coalesce(sum(amount),0) into amount_paid from records where kind='payment' and status in ('Paid','Reconciled') and details->>'expense_id'=source.id::text;
  if amount_paid+r.amount>source.amount then raise exception 'Payment exceeds the unpaid approved amount.';end if;
  if not exists(select 1 from attachments where record_id=r.id) then raise exception 'Attach payment evidence before recording payment.';end if;
  fid:=(b.details->>'fund_id')::uuid;
  perform post_entry(r,(r.details->>'account_id')::uuid,-r.amount,fid);
  perform set_record_state(source.id,case when amount_paid+r.amount=source.amount then 'Paid' else 'Partly paid' end);
 elsif r.kind='advance' and target='Paid' then
  select * into b from records where id=(r.details->>'budget_id')::uuid for update;
  if not exists(select 1 from attachments where record_id=r.id) then raise exception 'Attach payment evidence before recording payment.';end if;
  perform post_entry(r,(r.details->>'account_id')::uuid,-r.amount,(b.details->>'fund_id')::uuid);
 elsif r.kind='transfer' and target='Posted' then
  if r.details->>'from_account_id'=r.details->>'to_account_id' then raise exception 'Choose two different accounts.';end if;
  perform 1 from records where id in((r.details->>'from_account_id')::uuid,(r.details->>'to_account_id')::uuid) order by id for update;
  perform post_entry(r,(r.details->>'from_account_id')::uuid,-r.amount);
  perform post_entry(r,(r.details->>'to_account_id')::uuid,r.amount);
 end if;
end $$;
create function public.prepare_approval(r public.records) returns void language plpgsql security definer set search_path=public as $$
declare assignee uuid;
begin
 if r.kind='minutes' then
  assignee:=(r.details->>'approver_id')::uuid;
  if assignee is null or assignee=r.created_by or not exists(select 1 from profiles where id=assignee and active and roles&&array['chairperson','vice_chairperson']) then raise exception 'Choose a different authorized minutes approver.';end if;
 end if;
 insert into approval_requests(record_id,record_kind,title,summary,amount,currency,requested_by,assigned_to,record_version,snapshot) values(r.id,r.kind,r.title,r.description,r.amount,r.currency,r.created_by,assignee,r.version,form_details(r.kind,r.details));
end $$;
create or replace function public.transition_record(record_id uuid,target_status text,expected_version integer,action_note text default '') returns public.records language plpgsql security definer set search_path=public as $$
declare r records;allowed boolean:=false;d jsonb;dependent records;next_date date;new_task records;
begin
 select * into r from records where id=record_id for update;
 if not found or not can_access_record(r.id) or not can_write_kind(r.kind) then raise exception 'Access denied.';end if;
 if r.version<>expected_version then raise exception 'Record changed; reload and try again.';end if;
 d:=form_details(r.kind,r.details);
 if target_status<> 'Cancelled' then perform validate_details(r.kind,d,true);end if;
 if target_status in ('Scheduled','Held','Completed') and r.kind in ('meeting','activity') and (d->>'ends_at')::timestamptz<=(d->>'starts_at')::timestamptz then raise exception 'End time must be later than start time.';end if;
 if r.kind in ('expense','budget','advance','transfer','retirement','reconciliation') then
  if r.status in ('Draft','Returned') and target_status='Submitted' then
   if r.kind in ('expense','advance') then perform assert_budget(r);end if;if r.kind in ('expense','budget','advance','transfer') and r.amount<=0 then raise exception 'Enter a positive financial amount.';end if;allowed:=true;
  elsif r.kind='advance' and r.status='Approved' and target_status='Paid' then allowed:=has_role(array['treasurer','finance_manager','finance_officer']);
  elsif r.kind in ('advance','transfer') and r.status in ('Paid','Posted') and target_status='Voided' then allowed:=has_role(array['treasurer','finance_manager']);
  elsif r.kind='transfer' and r.status='Approved' and target_status='Posted' then allowed:=has_role(array['treasurer','finance_manager','finance_officer']);
  elsif r.kind='budget' and r.status='Approved' and target_status='Closed' then allowed:=has_role(array['treasurer','finance_manager']);end if;
 elsif r.kind='minutes' then allowed:=r.status in ('Draft','Returned') and target_status='In review';
 elsif r.kind='task' then
  allowed:=(r.status='To do' and target_status in ('In progress','Cancelled')) or (r.status='In progress' and target_status in ('Blocked','In review')) or (r.status='Blocked' and target_status='In progress') or (r.status='In review' and target_status in ('Completed','In progress'));
  if r.details->>'dependencies' is not null and target_status in ('In progress','Completed') and not exists(select 1 from records where id=(r.details->>'dependencies')::uuid and status='Completed') then raise exception 'Complete the dependency first.';end if;
  if target_status='Blocked' and coalesce(length(r.details->>'blocked_reason'),0)<3 then raise exception 'Describe the blocker first.';end if;
  if target_status='Completed' and exists(select 1 from jsonb_array_elements(coalesce(r.details->'checklist','[]')) c where lower(c->>1) not in ('yes','done','true')) then raise exception 'Complete the task checklist first.';end if;
  if target_status='Completed' and coalesce(length(r.details->>'evidence'),0)<3 then raise exception 'Add completion evidence first.';end if;
  if r.status='In review' and r.details->>'reviewer_id' is not null and (r.details->>'reviewer_id')::uuid<>auth.uid() then raise exception 'Only the assigned reviewer can complete this task.';end if;
 elsif r.kind='program' then allowed:=(r.status='Planned' and target_status='Approved') or (r.status='Approved' and target_status='Active') or (r.status='Active' and target_status in ('On hold','Completed')) or (r.status='On hold' and target_status='Active') or (r.status='Completed' and target_status='Archived');
 elsif r.kind='activity' then allowed:=(r.status='Planned' and target_status in ('Scheduled','Cancelled')) or (r.status='Scheduled' and target_status in ('In progress','Cancelled')) or (r.status='In progress' and target_status in ('Completed','Cancelled'));
 elsif r.kind='meeting' then allowed:=(r.status='Draft' and target_status in ('Scheduled','Cancelled')) or (r.status='Scheduled' and target_status in ('Held','Cancelled'));
 elsif r.kind='resolution' then allowed:=(r.status='Proposed' and target_status in ('Adopted','Cancelled')) or (r.status='Adopted' and target_status='In progress') or (r.status='In progress' and target_status='Implemented') or (r.status='Implemented' and target_status='Verified');
 elsif r.kind='correspondence' then
  allowed:=(r.status='Draft' and target_status in ('In review','Received')) or (r.status='In review' and target_status='Approved') or (r.status='Approved' and target_status='Sent') or (r.status in ('Sent','Received') and target_status='Awaiting response') or (r.status in ('Sent','Received','Awaiting response') and target_status='Closed');
  if target_status='Approved' and (r.created_by=auth.uid() or (r.details->>'approver_id')::uuid is distinct from auth.uid()) then raise exception 'A different assigned reviewer must approve this letter.';end if;
  if target_status='Sent' and coalesce(length(r.details->>'sent_reference'),length(action_note),0)<3 then raise exception 'Record evidence of sending first.';end if;
 elsif r.kind='donation' then allowed:=(r.status='Unverified' and target_status='Received' and has_role(array['treasurer','finance_manager','finance_officer'])) or (r.status='Received' and target_status='Voided' and has_role(array['treasurer','finance_manager']));
 elsif r.kind='payment' then allowed:=(r.status='Draft' and target_status='Paid') or (r.status='Paid' and target_status='Reconciled') or (r.status in ('Paid','Reconciled') and target_status='Voided' and has_role(array['treasurer','finance_manager']));
 elsif r.kind='account' then allowed:=(r.status='Draft' and target_status='Active') or (r.status='Active' and target_status='Closed');
 elsif r.kind='period' then
  allowed:=r.status='Open' and target_status='Closed';
  if allowed then perform assert_open_period((r.details->>'end_date')::date,r.currency);if coalesce(length(r.details->>'evidence'),0)<5 then raise exception 'Record period-close review evidence first.';end if;
   if exists(select 1 from records a where a.kind='account' and a.status='Active' and a.currency=r.currency and not exists(select 1 from records c where c.kind='reconciliation' and c.status='Approved' and c.details->>'account_id'=a.id::text and (c.details->>'end_date')::date=(r.details->>'end_date')::date and (c.details->>'statement_balance')::numeric=coalesce((select sum(amount) from ledger_entries le where le.account_id=a.id and le.currency=r.currency and le.posting_date<=(r.details->>'end_date')::date),0))) then raise exception 'Approve reconciliations for all active accounts before closing.';end if;
  end if;
 elsif r.kind='fund' then allowed:=r.status='Active' and target_status='Closed';
 elsif r.kind='pledge' then allowed:=r.status in ('Pledged','Partly fulfilled') and target_status='Cancelled';
 elsif r.kind='in_kind' then allowed:=(r.status='Expected' and target_status='Received') or (r.status='Received' and target_status='Distributed');
 elsif r.kind='campaign' then allowed:=(r.status='Draft' and target_status='Active') or (r.status='Active' and target_status in ('Completed','Cancelled'));
 elsif r.kind='interaction' then allowed:=r.status='Open' and target_status='Completed';
 elsif r.kind='indicator' then allowed:=r.status='Active' and target_status='Completed';
 elsif r.kind='document' then allowed:=(r.status='Draft' and target_status='Approved') or (r.status='Approved' and target_status='Archived');
 elsif r.kind='member' then allowed:=(r.status='Active' and target_status in ('Resigned','Suspended')) or (r.status='Suspended' and target_status in ('Active','Resigned'));
 elsif r.kind='beneficiary' then allowed:=(r.status='Open' and target_status='Assessed') or (r.status='Assessed' and target_status='Approved') or (r.status='Approved' and target_status='Active') or (r.status='Active' and target_status in ('Follow-up','Closed')) or (r.status='Follow-up' and target_status in ('Active','Closed'));
 end if;
 if r.kind in ('period','budget') and target_status='Closed' and (r.details->>'end_date')::date<(r.details->>'start_date')::date then raise exception 'Period end must follow its start.';end if;
 if r.kind in ('account','fund') and target_status='Closed' and exists(select 1 from ledger_entries where (r.kind='account' and account_id=r.id) or (r.kind='fund' and fund_id=r.id) group by currency having sum(amount)<>0) then raise exception 'Clear the recorded balance before closing.';end if;
 if not allowed then raise exception 'Transition not permitted.';end if;
 if r.kind in ('payment','donation','account','transfer','advance') then perform perform_financial_action(r,target_status,action_note);end if;
 if r.kind in ('resolution','activity','program') and target_status in ('Implemented','Verified','Completed') and coalesce(length(r.details->>'evidence'),length(r.details->>'verification'),0)<3 then raise exception 'Add completion evidence first.';end if;
 r:=set_record_state(r.id,target_status,jsonb_build_object('last_action_by',auth.uid())||case when r.kind='correspondence' and target_status='Sent' then jsonb_build_object('sent_reference',coalesce(nullif(action_note,''),r.details->>'sent_reference')) else '{}'::jsonb end||case when target_status='Voided' then jsonb_build_object('void_reason',action_note) else '{}'::jsonb end);
 if target_status in ('Submitted','In review') and r.kind in ('expense','budget','advance','transfer','retirement','reconciliation','minutes') then perform prepare_approval(r);end if;
 if r.kind='task' and target_status='Completed' and r.details->>'recurrence' in ('Weekly','Monthly') then
  next_date:=r.date+case when r.details->>'recurrence'='Weekly' then interval '7 days' else interval '1 month' end;
  insert into records(kind,title,status,amount,currency,date,category,description,assignee,program_id,parent_id,collaborators,created_by,details) values('task',r.title,'To do',0,r.currency,next_date,r.category,r.description,r.assignee,r.program_id,r.id,r.collaborators,r.created_by,form_details('task',r.details)-'evidence'-'blocked_reason'-'checklist');
 end if;
 return r;
end $$;
-- Remove the old three-argument RPC, which must not bypass new permissions.
drop function public.transition_record(uuid,text,integer);
create function public.decide_approval(approval_id uuid,approve boolean,note text default '') returns public.approval_requests language plpgsql security definer set search_path=public as $$
declare a approval_requests;r records;source records;balance numeric;returned numeric;
begin
 select record_id into a.record_id from approval_requests where id=approval_id;
 select * into r from records where id=a.record_id for update;
 select * into a from approval_requests where id=approval_id for update;
 if not found or a.status<>'Pending' or not may_decide(a) then raise exception 'Access denied.';end if;
 if r.version<>a.record_version or r.status not in ('Submitted','In review') then raise exception 'Record changed; reload and try again.';end if;
 if not approve and length(btrim(note))<3 then raise exception 'Explain what needs to change.';end if;
 -- Submission validates types and links while the author has access. The
 -- immutable snapshot can be approved without granting its reviewer that access.
 if approve and exists(select 1 from module_rules m,jsonb_array_elements(m.fields) f where m.kind=r.kind and coalesce((f->>'required')::boolean,false) and (r.details->(f->>'key') is null or r.details->(f->>'key') in ('null'::jsonb,'""'::jsonb))) then raise exception 'Complete all required form fields.';end if;
 if approve and r.kind in ('expense','advance') then perform assert_budget(r);end if;
 if approve and r.kind in ('budget','reconciliation') and (r.details->>'end_date')::date<(r.details->>'start_date')::date then raise exception 'Period end must follow its start.';end if;
 if approve and r.kind='reconciliation' and not exists(select 1 from records where id=(r.details->>'account_id')::uuid and kind='account' and currency=r.currency) then raise exception 'Reconciliation currency must match the account.';end if;
 if approve and r.kind='retirement' then
  select * into source from records where id=(r.details->>'advance_id')::uuid and kind='advance' for update;
  returned:=coalesce((r.details->>'returned')::numeric,0);
  if not found or source.status<>'Paid' or source.currency<>r.currency or returned<0 or r.amount+returned<>source.amount then raise exception 'Spent plus returned cash must equal the paid advance.';end if;
  if not exists(select 1 from attachments where record_id=r.id) then raise exception 'Attach receipts before approving accountability.';end if;
  if returned>0 then perform post_entry(r,(source.details->>'account_id')::uuid,returned,(select (details->>'fund_id')::uuid from records where id=(source.details->>'budget_id')::uuid));end if;
  perform set_record_state(source.id,'Settled');
 elsif approve and r.kind='reconciliation' then
  perform 1 from records where id=(r.details->>'account_id')::uuid for update;
  select coalesce(sum(amount),0) into balance from ledger_entries where account_id=(r.details->>'account_id')::uuid and currency=r.currency and posting_date<=(r.details->>'end_date')::date;
  if balance<>(r.details->>'statement_balance')::numeric then raise exception 'Reconciliation difference must be resolved before approval.';end if;
 end if;
 perform set_record_state(r.id,case when approve then 'Approved' else 'Returned' end,jsonb_build_object('approved_by',case when approve then auth.uid() else null end,'review_note',note));
 update approval_requests set status=case when approve then 'Approved' else 'Returned' end,decision_note=note,decided_by=auth.uid(),decided_at=now() where id=approval_id returning * into a;
 return a;
end $$;

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
 if r.kind='task' and r.details->>'reviewer_id'=uid::text then return true;end if;
 if r.kind='program' and p.roles&&array['treasurer','finance_manager','finance_officer','auditor'] then return true;end if;
 if r.kind in ('task','document','program','activity','indicator') then return own or member or p.roles&&array['administrator','executive_director','operations_manager'];end if;
 if r.kind in ('expense','budget') then return own or (r.kind='budget' and member) or p.roles&&array['treasurer','finance_manager','finance_officer','auditor'];end if;
 return true;
end $$;
create function public.recipient_approval_access(aid uuid,uid uuid) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from approval_requests a join profiles p on p.id=uid and p.active and (p.access_until is null or p.access_until>now()) where a.id=aid and a.requested_by<>uid and (a.assigned_to is null or a.assigned_to=uid) and
 case when a.record_kind='minutes' then p.roles&&array['chairperson','vice_chairperson'] when a.amount>coalesce((select (value->>a.currency)::numeric from organization_settings where key='approval_limits'),0) then p.roles&&array['chairperson','vice_chairperson'] else p.roles&&array['chairperson','vice_chairperson','treasurer','finance_manager','finance_approver'] end) $$;
create function public.recipient_notice_access(nid uuid,uid uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from notifications n where n.id=nid and n.user_id=uid and (recipient_record_access(n.record_id,uid) or recipient_approval_access(n.approval_id,uid)))$$;
create function public.can_read_notice(nid uuid) returns boolean language sql stable security definer set search_path=public as $$select is_active() and recipient_notice_access(nid,auth.uid())$$;
drop policy notifications_read on public.notifications;
create policy scoped_notifications_read on public.notifications for select to authenticated using(public.is_active() and user_id=auth.uid() and public.can_read_notice(id));
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
 for uid in select distinct x from unnest(array_append(array_append(new.collaborators,new.assignee),case when new.kind='task' then (new.details->>'reviewer_id')::uuid else null end)) x where x is not null and x<>auth.uid() loop
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

revoke all on public.module_rules,public.organization_settings,public.dispatch_health,public.approval_requests,public.program_members,public.ledger_entries,public.notification_deliveries,public.notification_preferences,public.record_comments from anon,authenticated;
grant select on public.approval_requests,public.program_members,public.ledger_entries,public.notification_deliveries,public.notification_preferences,public.record_comments,public.dispatch_health to authenticated;
grant insert,update on public.notification_preferences to authenticated;
grant insert on public.record_comments to authenticated;
-- All new security-definer helpers are private by default. Only the reviewed
-- RPCs and policy predicates below are exposed to authenticated clients.
do $$declare f record;begin for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('in_program','can_access_record','can_edit_record','set_program_member','may_decide','validate_details','validate_links','create_record_v3','form_details','assert_open_period','post_entry','set_record_state','assert_budget','perform_financial_action','prepare_approval','transition_record','decide_approval','recipient_record_access','recipient_approval_access','recipient_notice_access','can_read_notice','queue_notice','approval_event','claim_push_jobs','finish_push_job','prepare_due_reminders') loop execute format('revoke all on function %s from public,anon,authenticated',f.sig);end loop;end $$;
grant execute on function public.can_access_record(uuid),public.can_edit_record(uuid),public.may_decide(public.approval_requests),public.can_read_notice(uuid) to authenticated;
grant execute on function public.create_record_v3(jsonb),public.edit_record(uuid,integer,jsonb),public.transition_record(uuid,text,integer,text),public.decide_approval(uuid,boolean,text),public.set_program_member(uuid,uuid,boolean) to authenticated;
create function public.retry_my_push() returns integer language plpgsql security definer set search_path=public as $$declare n integer;begin
 if not is_active() then raise exception 'Access denied.';end if;
 update push_jobs j set attempts=0,available_at=now(),last_error=null where not j.done and j.attempts>0 and exists(select 1 from push_subscriptions s where s.id=j.subscription_id and s.user_id=auth.uid()) and recipient_notice_access(j.notification_id,auth.uid());
 get diagnostics n=row_count;return n;end $$;
revoke all on function public.retry_my_push() from public,anon;
grant execute on function public.retry_my_push() to authenticated;
grant execute on function public.claim_push_jobs(),public.finish_push_job(uuid,boolean,boolean,text),public.prepare_due_reminders() to service_role;
-- Recreate review queues for pre-upgrade submitted records, without inventing
-- missing form details. Reviewers can return incomplete requests for correction.
insert into approval_requests(record_id,record_kind,title,summary,amount,currency,requested_by,record_version,snapshot)
select id,kind,title,description,amount,currency,created_by,version,form_details(kind,details)
from records where status in ('Submitted','In review') and kind in ('expense','budget','advance','transfer','retirement','reconciliation','minutes') and not exists(select 1 from approval_requests where record_id=records.id);
commit;
