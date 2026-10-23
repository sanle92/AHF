# Aminia Hope Foundation — private management workspace

Version 0.3.0. A Shopify-style staff PWA for phone, tablet and laptop, with the official AHF logo and green/gold branding. The public website and its CMS remain separate.

**Delivery status:** source implementation, SQL workflow tests, and a Cloudflare Worker build. Nothing has been deployed or connected to your live Supabase project here. Keep demo mode off for real use. No real beneficiary, donor, donation or financial records have been invented.

## What changed

- **19 roles** with module permissions, programme membership, assigned records, and server/database enforcement. Secretary records and files are accessible only to Secretary and Administrator.
- A separate **Approvals** inbox gives authorized leadership/finance reviewers only the submitted snapshot. Chairperson/Vice-Chairperson can review minutes without opening the secretary workspace. Requests cannot approve themselves.
- **Secretary:** structured meeting agendas, attendance, Kampala start/end times, calendar view and .ics export; minutes with discussions, votes/conflicts, actions and amendment references; resolutions, implementation/evidence, correspondence review/delivery records and membership register.
- **Tasks:** list, board and calendar; priorities, owner/collaborators, checklist, dependency, blocker, reviewer, evidence, discussion and weekly/monthly recurrence after completion.
- **Finance:** separate budgets, expense requests, actual payments, accounts, restricted/unrestricted funds, transfers, cash advances, accountability/returned cash, reconciliations and period close. Append-only ledger and documented reversal entries; partial payments, budget limits, account/fund balance controls and currency checks. Approval never implies payment.
- **Donors:** contacts, outreach consent/preferences, campaigns, pledges and partial receipts, in-kind gifts, follow-ups, linked work and downloadable acknowledgment drafts. No email or receipt is sent automatically.
- **Programmes:** objectives, responsible staff, membership, activities, milestones, risks, measurable indicators, targets/actuals, evidence and counting rules.
- **Notifications:** foreground inbox popups, private device push, deadline reminders, preferences, separate local/server tests, device repair after VAPID rotation, scheduler heartbeat, delivery attempt history and retry of your failed deliveries.
- Attachments, comments, version conflict protection, scoped CSV reports and application audit trail.

The shared operational register has explicit module form schemas and private database RPCs. Financial postings and approval snapshots have separate tables. The service worker caches only the non-sensitive offline fallback and icon; confidential records require connectivity.

## Local use and checks

Use Node 24 (minimum 22.13) and the pnpm version in package.json. Run commands from the extracted **ahf-management** directory containing package.json. Running them in the archive's parent directory causes “No package found in this workspace.”

~~~sh
corepack enable
pnpm install --frozen-lockfile
cp .env.example .dev.vars
pnpm dev
~~~

The default is a read-only organization view until the backend is configured. Explicit AHF_DEMO_MODE=true enables a browser-local synthetic walkthrough; it is never imported into the private backend. Do not enter personal data in demo mode.

~~~sh
pnpm typecheck
pnpm test
pnpm lint
pnpm build:cloudflare
~~~

Tests run real application SQL in PostgreSQL via PGlite with minimal Supabase-owned auth/storage schemas. They cover role/scope denial, private minutes review, no self-approval, stale versions, payment evidence, budget controls, partial pledges, ledger reversals, advances/retirement, transfers, period close, currencies, task reviewer/recurrence, MFA denial, push retry and revocation. This does not replace managed Supabase/device integration testing.

## Install or upgrade the database

Use a private Supabase project, separate from public website content. Disable public signup and provision individual staff Auth accounts.

- **New database:** apply migrations 001, 002, 003 and **004_management_upgrade.sql**, in order.
- **Existing v0.2 database with 001–003 applied:** back up first, test on a staging copy, then apply **004 only**. Do not rerun 001.
- The migration is transactional and preserves existing IDs. It adds roles, scopes, forms, approvals, ledger and notification controls. Existing Pending expenses become Submitted. Existing submitted records receive review snapshots; incomplete records should be returned for completion.
- Historical Received/Paid entries are marked **legacy_unposted** and are not guessed into the new ledger. Establish a documented cutover date, verified opening balances and reconciliation before trusting balances. Do not count old transactions again against a cutover balance.
- Existing programme/case assignments need review: access now follows ownership, responsible people and programme membership. Use the programme detail view to grant appropriate programme memberships.
- Enable Supabase TOTP MFA. All private data and Storage policies require an aal2 session, active profile and unexpired access_until. The server validates the session against Supabase Auth.

Configure .dev.vars locally; configure the same values as Cloudflare runtime secrets later:

~~~text
AHF_DEMO_MODE=false
AHF_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
AHF_SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_JWT_KEY
AHF_VAPID_PUBLIC_KEY=
AHF_VAPID_PRIVATE_KEY=
AHF_VAPID_SUBJECT=mailto:YOUR_MONITORED_ADDRESS
AHF_SUPABASE_SERVICE_ROLE_KEY=
AHF_PUSH_DISPATCH_SECRET=
~~~

Only the public URL, public anon key and VAPID public key reach the browser. Ordinary data requests use the signed-in user's token and RLS. The service role is reserved for the protected push dispatcher.

## Team roles

Co-founder is an organizational title, not permission to every record. Combine roles only when a person actually holds those responsibilities.

| Responsibility | Role keys | Access |
| --- | --- | --- |
| Governance review | chairperson, vice_chairperson | Specific approval snapshots, own tasks/documents |
| Administration | administrator | Secretary and operations; finance request preparation, no automatic treasury access |
| Secretary | secretary | Meetings, minutes, resolutions, correspondence, membership |
| Executive/operations | executive_director, operations_manager | Operational programmes/tasks; scoped finance requests |
| Programme delivery | programme_manager, program_officer | Owned/assigned/member programmes, activities and cases |
| Casework | case_worker | Assigned/member programme cases; no treasury or secretary access |
| Monitoring | monitoring_officer | Assigned/member programme indicators |
| Fundraising | donor_relations, fundraising_manager | Donors, campaigns, pledges, follow-ups, unverified contributions |
| Treasury | treasurer, finance_manager | Finance workflow, accounts/funds, donor records and permitted approvals |
| Finance processing | finance_officer | Finance preparation, verified receipts/payments, no approval privilege |
| Finance review | finance_approver | Specific financial approval snapshots |
| Volunteer coordination | volunteer_coordinator | Assigned/member activities, task delegation |
| Volunteer | volunteer | Own/assigned tasks and member activities |
| Audit | auditor | Read-only financial records and permitted audit history; own tasks |

Secretary workspace access always requires secretary or administrator. Programme membership never grants an additional role.

Default financial review thresholds are in organization_settings (approval_limits): UGX 500,000; USD 200; EUR 200; GBP 150; KES 20,000. Larger requests require Chairperson/Vice-Chairperson. Smaller requests permit an independent Treasurer, Finance Manager or Finance Approver as well. These are starter configuration values for your governance team to adopt or change, not statements of AHF policy. Different currencies are never added together or converted automatically.

supabase/team-existing.sql contains only the two Auth IDs you supplied: Sanle Esaie (Administrator) and Aziko Paula (Treasurer/Secretary). It creates no Auth accounts. Role changes remain an administrator's database operation; no client can promote itself. With only those roles, arrange an independent authorized reviewer before submitting financial requests. A person's own request will remain unapprovable by that same person.

## Cloudflare commands — deploy later

This is a Cloudflare **Worker** application, not a static-only Pages export. Supabase supplies PostgreSQL/Auth/Storage; no D1 database is required.

| Field | Command |
| --- | --- |
| Build | pnpm run build:cloudflare |
| Deploy | pnpm run deploy:cloudflare |
| Local production preview, after build | pnpm run preview |

The generated Worker config is dist/server/wrangler.json; client assets are in dist/client. Deployment happens only when you run the deploy command. The deployment name comes from localBindingConfig in vite.config.ts.

~~~sh
pnpm exec wrangler login
pnpm exec wrangler secret put AHF_SUPABASE_URL --config dist/server/wrangler.json
pnpm exec wrangler secret put AHF_SUPABASE_ANON_KEY --config dist/server/wrangler.json
pnpm exec wrangler secret put AHF_DEMO_MODE --config dist/server/wrangler.json
~~~

Enter false for production demo mode. Add the other runtime secrets the same way. Keep private values out of commands, source control and public build variables. Set your HTTPS app domain and configure its URL in Supabase Auth.

## Push setup and troubleshooting

~~~sh
pnpm push:keys
~~~

This prints a VAPID pair and a separate random dispatch secret **on your own computer**. Store the pair safely; do not rotate it casually. AHF_VAPID_SUBJECT must be a real monitored contact.

For scheduled reminders and queued event notifications:

1. Set AHF_APP_URL in deploy/wrangler.scheduler.jsonc to your actual HTTPS app origin.
2. Deploy the scheduler separately and give it the same dispatch secret as the app.

~~~sh
pnpm exec wrangler deploy --config deploy/wrangler.scheduler.jsonc
pnpm exec wrangler secret put AHF_PUSH_DISPATCH_SECRET --config deploy/wrangler.scheduler.jsonc
~~~

3. Staff sign in, open Settings, choose **Enable / repair this device**, then run **Test device popup** and **Test server push**.
4. If the device test succeeds but server push fails, check VAPID pair/subject and the reported HTTP failure.
5. If server tests work but normal events do not, check scheduler last run, roles/assignments, preferences and delivery history. Failed jobs retry automatically and can be queued again from Settings.
6. Register each phone/tablet/laptop separately. Sign-out removes the current device's registration; it does not revoke the other devices. Account/session revocation is a separate Supabase administration action.

Foreground polling checks the inbox every 15 seconds while visible; new items show an in-app toast. Record synchronization runs every minute and on focus. Initial inbox loading does not flood the screen with old popups.

The scheduler checks due tasks, meetings, follow-ups, correspondence and advances, deduplicates reminders by due item/day, and claims up to 20 jobs every five minutes. Failed jobs receive up to five automatic attempts; expired subscriptions are removed. Recipients are checked before creation and again at dispatch, so role/membership revocation stops queued delivery. Push is at least once, not guaranteed; retries can duplicate messages. Lock-screen content is generic. Opening a notification returns to its permitted record or the Approvals inbox.

Focus mode, OS/banner settings and battery/network restrictions can suppress popups even after the push provider accepts the message. On iPhone/iPad, open the Home Screen installation before enabling push. Test actual team devices; the HTTPS deployment, real VAPID credentials and physical-device delivery were unavailable here.

Meeting .ics files can be imported into a calendar; they do not send invitations or synchronize calendar changes automatically. Weekly/monthly meeting recurrence is included in the calendar export. Internal meeting reminders apply to the stored meeting occurrence. Recurring tasks create their next record after completion.

## Operational boundaries

This release is an operational finance cashbook/approval system, not a statutory general ledger with accrual journals, payroll, tax filing, exchange rates, bank feeds or automatic payments. Recording a payment never moves money. Acknowledgments are reviewable downloads, not tax-receipt certification. Programme outputs are not automatically unique people reached.

Beneficiary records remain a limited scoped support register. Detailed safeguarding investigations, medical narratives, electronic signatures and safeguarding escalation are not implemented. Do not put them in general notes.

Private PDF/JPG/PNG files are limited to 10 MB, with 60-second signed access links. Malware scanning is not included. Private records are not available for offline editing. The interactive API refuses datasets of 10,000 or more records rather than silently returning incomplete totals; add server-side paging/reporting before that scale.

Role provisioning, account recovery and backups are managed through Supabase. Audit rows and ledger postings cannot be altered by ordinary application clients; infrastructure owners still administer the database. Back up database **and file bytes**, test restoration and complete docs/ACCEPTANCE.md before operational rollout.

The official organization facts/provenance remain in docs/DATA-SOURCES.md. Unknown contact information has not been invented. Proposed programme areas initialize only as Planned.
