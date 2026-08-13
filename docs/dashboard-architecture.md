# Dashboard architecture — Acme Agentic Experience Board

There are two dashboards at two deliberate altitudes. `agenticExperienceBoard`
("Acme Agentic Experience — Board View") is Acme's own C-suite view: the recruitment-tech
ISV (~$500M revenue, ~400 enterprise customers) reporting to its board on the one-quarter
agentic-hiring mandate after losing its largest enterprise logo to an AI-native competitor.
`customerPipelineDashboard` ("Acme for Customers — Pipeline View") is the product Acme ships —
what one staffing customer sees — kept as a separate component for Q&A.

Both are pure presentation layers bound to typed Apex contracts
(`AgenticExperienceBoardController` / `CustomerPipelineController`); the components know
nothing about where numbers come from. `getCandidateSideStats()` is a real `WITH USER_MODE`
SOQL query against Contacts — on the board view it feeds the "+25 live in this workspace"
badge, framing this org as one pilot customer workspace, and it respects the viewer's own
record access, consistent with the zero-data-by-default story `SecurityBeatTest` proves.
`getBoardMetrics()` serves everything else from a deterministic seeded dataset behind the
same contract: no randomness, so rehearsal and the live run are identical. The `DEMO SEED`
comment block marks the swap point — in production that method body is replaced by Tableau
Next semantic queries, Data Cloud calculated insights, or a CRM Analytics query, and the LWC
contract does not change; if a customer already lives in Tableau, the alternative is
embedding an existing viz with the Tableau Viz LWC on the same app page. Charts are
hand-rolled inline SVG with zero external dependencies — no Chart.js, no static resources,
no CDN — which keeps Lightning Web Security happy and removes the demo's biggest reliability
risk. Everything deploys as plain metadata (`LightningComponentBundle`, `ApexClass`,
`FlexiPage`, `CustomTab`, `PermissionSet`) with the same CLI-and-git governance as the rest
of this build.
