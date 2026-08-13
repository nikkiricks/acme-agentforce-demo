# Dashboard architecture — Agentic Experience Board

The `agenticExperienceBoard` LWC is a pure presentation layer bound to a typed Apex contract
(`AgenticExperienceBoardController` and its inner DTO classes); it knows nothing about where
the numbers come from. `getCandidateSideStats()` is a real `WITH USER_MODE` SOQL query against
Contacts, so one number on screen — candidates screened by agent — is truthfully live from CRM
and respects the viewer's own record access, consistent with the zero-data-by-default story
`SecurityBeatTest` proves. `getBoardMetrics()` serves everything else from a deterministic
seeded dataset behind the same contract: no randomness, so rehearsal and the live run are
identical. The `DEMO SEED` comment block in the controller marks the swap point — in
production that method body is replaced by Tableau Next semantic queries, Data Cloud
calculated insights, or a CRM Analytics query, and the LWC contract does not change. If a
customer already lives in Tableau, the alternative is embedding an existing viz with the
Tableau Viz LWC on the same app page. The chart is hand-rolled inline SVG with zero external
dependencies — no Chart.js, no static resources, no CDN — which keeps Lightning Web Security
happy and removes the demo's biggest reliability risk. Everything deploys as plain metadata
(`LightningComponentBundle`, `ApexClass`, `FlexiPage`, `CustomTab`) with the same
CLI-and-git governance as the rest of this build.
