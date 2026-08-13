# Acme Enterprise — CLI-First Agentforce Hiring Demo

**🏢 Live demo — Acme Talent Console:** <https://nikkiricks.github.io/acme-agentforce-demo/acme-dashboard.html>
(GitHub Pages copy of [docs/acme-dashboard.html](docs/acme-dashboard.html) — what Acme's recruiters would see)

An Agentforce agent that does recruiter-grade bulk candidate triage against live CRM data —
built, deployed, tested, and versioned **entirely from the terminal**. The Agentforce Builder
UI was never opened. That's the point: under a customer constraint of "AI screening must be
governed and auditable," the audit trail and the build are the same git history.

## What it does

Ask the agent (as a recruiter):

- **"How many candidates have applied?"** → real count from CRM via a flow-backed action
- **"Screen all candidates on file for: \<job req\>"** → ranked shortlist from 25 CRM candidate
  profiles, full rationale for the top 5, ⚠ flags for the 60–75 human-review band, AI-padded
  resumes called out with the specific skills-vs-history mismatch
- **"Draft a short outreach email to \<candidate\>"** → grounded outreach from the candidate's
  actual profile

Under the hood:

| Piece | Source | Notes |
|---|---|---|
| Agent (Agent Script) | `force-app/main/default/aiAuthoringBundles/Acme_Enterprise/` | subagent routing, screening rubric, 2 flow-backed actions |
| `Get_Candidate_Profiles` flow | `force-app/main/default/flows/` | authored as raw XML — `runInMode` and `status=Active` declared in source |
| `Count_Candidates` flow | `force-app/main/default/flows/` | |
| 25-candidate roster | `data/candidates-v2.csv` | 17 rows; mix of stars, borderline, AI-padded, wrong-role |
| Agent test suite (5-case ladder) | `tests/agent/acme-triage-testspec.yaml` | topic + action + LLM-judge assertions |
| Security proof | `force-app/main/default/classes/SecurityBeatTest.cls` | zero-data-by-default as a runnable Apex test |
| Exec board dashboard (LWC) | `force-app/main/default/lwc/agenticExperienceBoard/` | 4 KPI tiles, hand-rolled SVG trend, D/W/M toggle, two-sides pipeline strip — see `docs/dashboard-architecture.md` |
| Board data service + tests | `force-app/main/default/classes/AgenticExperienceBoardController*.cls` | pluggable insight layer: one live CRM query today, Data Cloud / Tableau Next tomorrow |

## Run it yourself

Prereqs: a [Developer Edition org with Agentforce](https://developer.salesforce.com/signup),
the [`sf` CLI](https://developer.salesforce.com/tools/salesforcecli) (built on 2.145.6).

```bash
git clone <this repo> && cd acme_enterprise-agentic_hiring_platform-demo
sf org login web --alias renewal-org --set-default
export FORCE_COLOR=0   # if your shell forces color, `sf --json` output gets corrupted
```

**1. Deploy flows + test class** (plain Metadata API works for these):

```bash
sf project deploy start -m "Flow:Get_Candidate_Profiles" -m "Flow:Count_Candidates" -m "ApexClass:SecurityBeatTest"
```

**2. Import the roster** (count first — the import is a pure insert; re-running it on an
intact roster creates duplicates):

```bash
bash scripts/verify-roster.sh          # only import if the count is short
sf data import bulk --sobject Contact --file data/candidates-v2.csv --line-ending CRLF --wait 10
```

`--line-ending CRLF` is mandatory (the Bulk API rejects the file otherwise). A fresh org lands
at **17** candidates; the original demo org had 8 pre-existing contacts, which is where the
"25" in the test expectations comes from — on a fresh org, edit case 1 of
`tests/agent/acme-triage-testspec.yaml` to expect 17, or import 8 more contacts with
`@example.com` emails.

**3. Publish + activate the agent.** The agent does NOT deploy via the Metadata API
(`sf project deploy start -m "AiAuthoringBundle:..."` fails — see the journal). The working
path:

```bash
sf agent validate authoring-bundle -n Acme_Enterprise
sf agent publish authoring-bundle              # may exit non-zero with "fetch failed" — see gotchas
sf agent activate                              # activate the new BotVersion
```

Then give the router's classifier a few minutes: it **reindexes asynchronously** after
activation, so routing changes lag the publish.

**4. Run the test ladder:**

```bash
sf agent test create --spec tests/agent/acme-triage-testspec.yaml \
  --api-name Acme_Enterprise_Triage_Ladder --force-overwrite -o renewal-org
sf agent test run --api-name Acme_Enterprise_Triage_Ladder -o renewal-org --wait 10
```

Expected: Topic 5/5, Action 4–5/5, Outcome 3–4/5. Case 2 is a known standing finding (the
agent asks for a job description instead of listing applicants); case 4's LLM judge is
volatile run to run. `docs/demo-tests.md` has the per-case detail.

**5. Talk to it live:**

```bash
sf agent preview -n Acme_Enterprise -o renewal-org --use-live-actions
```

`--use-live-actions` matters — without it, preview *simulates* the flow calls with AI instead
of running them.

**6. Run the security proof:**

```bash
sf apex run test --tests SecurityBeatTest --result-format human --wait 10
```

**7. Look at it in the Salesforce UI** (optional — the whole point of this build is that the
UI is a preview window, not the workbench, but seeing it is believing it):

```bash
sf org open                                              # org home, logged in
sf org open -p "/lightning/setup/EinsteinCopilot/home"   # Agentforce Agents — open "Acme Enterprise" for the Builder view + preview pane
sf org open -p "/lightning/setup/Flows/home"             # the two CLI-authored flows
sf org open -p "/lightning/o/Contact/list"               # the 25-candidate roster
sf org open -p "/lightning/n/Agentic_Experience_Board_View"  # exec board dashboard (Agentic Experience — Board View)
```

Everything you'll see there — the agent's topics and actions, the active flow versions, the
contacts — was put there from the terminal; nothing was authored in these screens. Add
`--url-only` to any of the above to print a login URL instead of opening a browser.

## Giving the demo

**Client-facing dashboard:** [docs/acme-dashboard.html](docs/acme-dashboard.html) — the
Acme Talent Console, a self-contained demo page (works offline, no server) showing what
Acme's recruiters would see: a chat panel for the screening assistant, the rubric band
rail, the 17-profile roster, and the outreach queue. Open it with:

```bash
open docs/acme-dashboard.html
```

`docs/demo-runbook.md` is the verbatim 5-beat script with fallbacks and a night-before
checklist. The story it tells: `docs/pov-brief.md` (point of view + evidence table),
`docs/build-journal.md` (every docs lookup scored honestly — 33 questions, 17 answered,
10 failed), `docs/demo-tests.md` (the ladder, with real results).

## Platform gotchas (hard-won — each cost real time)

| Gotcha | Reality |
|---|---|
| `AiAuthoringBundle` via Metadata API | Retrieve AND deploy fail ("Entity type not available in this api version"). `sf agent publish authoring-bundle` is the only working path. |
| Bundle folder name | Must equal the agent's `config.developer_name`, or publish fails with `CannotFindBundle` — the `-n` flag doesn't override the folder lookup. |
| Spurious `fetch failed` (exit 10) | `sf agent publish` and `sf agent test run --wait` both emit it **on success**. Never trust the exit code — re-query (`BotVersion` for publish, `sf agent test results --job-id` for runs). |
| Router ignores instruction edits? | The classifier keys on transition-action/subagent `description:` fields, and reindexes asynchronously after activation. A correct fix can look broken for minutes. |
| Test assertions reject topic/action names | The framework wants short developer names (`candidate_screening`, `GetCandidateProfiles`), not the org-suffixed full names its own generator suggests. |
| `--use-most-recent` on `sf agent test results` | Appears in the command's own help examples; doesn't exist in CLI 2.145.6. Use `--job-id`. |
| Bulk API CSV import | Requires `--line-ending CRLF`; auto-detection guesses LF and rejects the file. |
| Data Import Wizard (UI, from V1) | Silently maps Contact descriptions onto Account — the Bulk API path in this repo avoids the wizard entirely. |
