# AHF Workspace v0.3 acceptance

## Completed locally

- TypeScript compilation, ESLint and the Cloudflare Worker production build.
- 21 passing tests, including PostgreSQL execution of all four migrations.
- Client module schemas checked against SQL module rules.
- Role and programme scope, MFA denial, expired/inactive access, and private file reads.
- Secretary records denied to leadership; leadership reviews submitted minutes snapshots.
- Independent approval, configured thresholds, locked review versions and stale-write rejection.
- Approved budget limits, actual payment evidence, partial payments and immutable ledger corrections.
- Partial pledge receipts, receipt reversal and restored outstanding pledge state.
- Advances, accountability, returned cash, transfers, reconciliations and period close.
- Currency mismatch and whole-UGX precision rejection.
- Assigned task reviewer, completion evidence/checklist and recurring next task creation.
- Push job claiming, failed delivery history, manual retry and post-revocation denial.
- Calendar UTC conversion from Kampala, UTF-8 line folding and CSV formula protection.
- Desktop browser walkthrough: meeting creation with agenda, time persistence, scheduling/calendar, secretary navigation restriction, treasury modules and settings.
- Demo mode restored to false after QA. No deployment or live records were created.

## Required on the organization's staging environment

1. Back up the existing private project and stored file bytes. Apply 004 only if 001–003 already exist. Test restoring both records and documents.
2. Verify the two existing Auth IDs, approved profile roles and independent reviewers. Do not give a person approval privileges simply to approve their own request.
3. Decide approval thresholds, opening-balance/cutover treatment and finance responsibilities. Historical transactions are marked unposted until reconciled through a documented cutover.
4. Sign in with real accounts; exercise authenticator enrollment, verification, refresh, sign-out, recovery and access revocation. Test direct REST and Storage reads as well as UI navigation.
5. Test programme membership grant/revoke and cross-programme denial with at least two operational accounts.
6. Submit minutes as Secretary, review as Chairperson/Vice-Chairperson, then confirm that the reviewer still cannot open secretary records/files.
7. Run the finance workflow with staged documents and known expected balances. Confirm that approval does not create a payment, and account/fund/currency/period rules hold.
8. Verify uploads, signed-link expiration, file limits and malware-handling procedures.
9. Configure production VAPID keys, monitored subject/contact, service key and dispatch secret. Deploy the scheduler separately and confirm its heartbeat.
10. Install the PWA on real Android, iPhone/iPad, tablet and laptop devices. Test device popup, server push, assignments, approval requests, reminders, retry, disabled preferences and lost-device handling.
11. Verify Focus mode and OS notification settings; provider acceptance alone is not proof of a visible banner.
12. Review retention, beneficiary minimization, safeguarding boundaries, account recovery and operational procedures before entering real sensitive records.

No live backend credentials, deployed app URL, production subscriptions or physical devices were supplied. Managed Supabase/Auth/Storage integration and real push display remain unverified. This release supplies an operational cashbook and approvals; statutory accrual accounting, payment execution, safeguarding investigations and automatic calendar synchronization are outside its implemented scope.
