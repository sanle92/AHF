# Foundation data and provenance

The interface uses the official logo provided by the user on 22 October 2026. The original JPEG is included unchanged at `public/brand/ahf-logo.jpeg`; app icons are scaled copies.

Organization facts come from `Aminia_Hope_Foundation_Updated_Draft_Constitution.docx`, dated 18 October 2026, and the logo supplied in this conversation:

| Fact | Source | Treatment |
| --- | --- | --- |
| Foundation name | Constitution Article 1 | Organization identity |
| Vision and mission | Articles 3–4 | Organization overview; mission condensed |
| Four founders and assigned responsibilities | Article 9 | Confirmed role assignments, not authenticated accounts |
| Eight programme areas | Article 7 | Proposed areas; never counted as active delivery |
| Wakiso District | Cover and Article 1.4 | Initial intended area |
| Registration status | Draft note and Article 1 | Preparing documents; never labelled registered |
| Official contacts/address/sub-county | Article 1.3–1.4 | Unknown; no invented contact details |
| Tagline | User-supplied official logo | “Empowering People · Strengthening Communities · Building a Brighter Future” |

The draft’s final checklist still mentions Katakwi, inconsistent with its cover and Article 1.4 and the user’s stated Wakiso location. This build follows the explicit Article 1.4 and user-provided district. The founders should correct that checklist in their constitution separately.

No donation amounts, donor identities, beneficiary records, completed activities, financial balances, official contact details, registration numbers, or operational dates have been supplied. None are generated as real data. Without a backend, the interface says “Not connected”; a connected empty register shows that no records are saved.

The old synthetic walkthrough remains available only through an explicit `AHF_DEMO_MODE=true` setting. Its browser-local storage is never imported into the live database.

Live data must be created or imported into the configured private Supabase project through authorized workflows. No external backend has been configured or written to in this update.
