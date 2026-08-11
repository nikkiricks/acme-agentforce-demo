# Acme Enterprise Demo V2 — CLI-First Rebuild — Design

**Date:** 2026-08-11
**Deadline:** Demoable today (Hemant coaching call tomorrow/Wed; panel Friday)
**Org:** `renewal-org` (`nikki.ricks.ed23f8f2dd0c@agentforce.com`, `00Dbm00000sDXiEEAW`) — same org that hosts the V1-built Acme agent (`0Xxbm0000035JrVCAU`)
**Workspace:** `acme_enterprise-agentic_hiring_platform-demo/` (this folder), tracked in the existing git repo

## Thesis — the defensible position

Under a customer constraint of "we need governed, auditable AI agents," prove the entire
agent lifecycle — author, deploy, data load, test, version — runs from source control and
the `sf` CLI, with the Salesforce UI reduced to a preview window. Every UI failure mode
from the V1 build (documented in `../demosessionhandoff.md` §2) gets a named CLI antidote.
The build itself tests Salesforce's two claims — robust docs and security by default —
and logs the evidence either way.

## Decisions made in brainstorming

1. **Strategy:** Retrieve + extend CLI-first. The working committed V1 agent is the safety net.
2. **Deliverable shape:** Bulk-triage conversation is the climax; the terminal build story wraps it; a POV brief closes it for Hemant.
3. **Docs/security test rigor:** live build journal scoring every docs lookup, plus one staged security beat. Not a full audit.
4. **Timeline:** build today; stop-building rule applies (rehearsal time is protected).
5. **Addition (user):** demo tests — the demo's question ladder becomes a repeatable, CLI-run test suite.

## Components

### 1. Scaffold + retrieve
- SFDX project in this folder (`sfdx-project.json`, `force-app/main/default/`), committed to git.
- Retrieve from `renewal-org`: the Acme agent's `aiAuthoringBundle`, `Count_Candidates` flow, and
  directly related GenAI metadata. Baseline commit before any edit.
- First act: determine the agent's actual version state (V1 handoff's unfinished "is it committed?"
  task) via CLI/Tooling API. If commit state is UI-only, that is journal finding #1.

### 2. Data — 25-candidate roster via Bulk API
- Generate roster CSV per handoff spec: ~3 clear stars, ~4–5 borderline (60–75 band), several
  AI-padded (skills unsupported by history), ~2 wrong-role, rest middling. Descriptions 60–80 words.
  Emails `@example.com` (load-bearing filter). Superset of the existing 8; dedupe by email.
- Import with `sf data import bulk` (Contact), structurally avoiding V1's Data Import Wizard
  mapping gotchas. Verify with `sf data query` count.

### 3. `Get_Candidate_Profiles` flow — authored as XML
- Local `flow-meta.xml`: Get Records (Contact, Email contains `example.com`) → Loop → Assignment
  appends name/title/Description to `profilesText` (Text, available for output) via text template.
  `requestNote` dummy input (Text, available for input) satisfies the ≥1-input platform rule.
- Baked into source: `status=Active` (kills V1's edited-but-inactive failure) and
  `runInMode=SystemModeWithoutSharing` (resolves V1's run-context mystery explicitly and reviewably).
- Verified before agent wiring by executing from anonymous Apex (`Flow.Interview`) — CLI
  equivalent of Flow Debug. Expect all candidates' text.

### 4. Agent wiring — Agent Script edited locally, deployed as source
- In `candidate_screening`: action definition `GetCandidateProfiles` (target
  `flow://Get_Candidate_Profiles`, input `requestNote` string required non-user, output
  `profilesText` string) in the `actions:` block; reference-only entry in `reasoning.actions`
  with `with requestNote = "..."`; triage instruction (call the action for screen-all requests;
  full rationale for top 5 + all human-review flags; summarize the tail).
- All V1 syntax rules respected (no `with` inside definitions; `flow://` targets only; access
  block untouched — enforced by diff review).
- Deploy with `sf project deploy start`.

### 5. Demo tests — the ladder as a repeatable suite
- **Flow layer:** anonymous Apex assertions — profiles output non-empty, contains known names,
  count matches roster.
- **Agent layer:** Agentforce testing via CLI (`sf agent test` with a test definition authored as
  metadata) covering the ladder: count question → expected ~25; "who has applied?" → list;
  full triage with job req → shortlist with flags; outreach draft. Assertions on topic routing,
  action invocation, and grounded output where the framework supports them.
- If the CLI test framework is unavailable/unusable in this org, that is a first-class journal
  finding and the ladder falls back to scripted manual preview (Builder preview = the single
  permitted UI touch), still recorded as a checklist in the repo.

### 6. Security beat (staged, reproducible)
- Show zero-data-by-default: the profiles query run in default user context vs.
  `SystemModeWithoutSharing` — the agent saw nothing until access was granted deliberately, in
  reviewable source. One command each side, scripted so it can run live.

### 7. Evidence artifacts (the Hemant wrap-up)
- `docs/build-journal.md` — every docs lookup logged live: question → doc consulted → verdict
  (answered / partial / failed). Honest scoring; failures are more valuable than wins.
- `docs/pov-brief.md` + polished Artifact page — one screen: the customer constraint, the
  position, evidence table (V1 UI pain → V2 CLI antidote), docs scorecard, security findings,
  demo-test results, art-of-the-possible close. Written in Hemant's vocabulary (point of view,
  art of the possible, PoC).

## Data flow

Recruiter question → agent router → `candidate_screening` → `GetCandidateProfiles`
(`flow://Get_Candidate_Profiles`) → Contact records (Description profiles) → LLM triage per
screening instructions (score bands, ⚠ 60–75, never-reject, equitable-treatment) → triaged
shortlist with rationale.

## Error handling / risks

- **Agent bundle doesn't round-trip** (UI-built agent fails retrieve or redeploy): flow + data +
  tests stay CLI-built; the one agent edit happens in the UI *code view* (never the assistant),
  journaled as a platform finding. POV stays honest.
- **CSV text quoting** (commas/newlines in Descriptions): generate RFC-4180-quoted CSV; verify a
  sample record's Description round-trips intact.
- **`sf agent` commands blocked** (plugin/auth/org edition): journal it; fall back per §5.
- **Anything blocks past mid-session:** stop-building rule. Committed V1 agent still works; V2's
  story becomes journal + brief + whatever cleared.

## Out of scope (YAGNI)

Data 360 wiring, record-triggered auto-screening, candidate-facing agent, new LWC/UI, deck work.
All remain slide material per the handoff.

## Success criteria

1. Count question returns the new roster size, live from CRM, via the CLI-deployed flow.
2. Full triage returns a readable shortlist: full rationale for top 5 + flagged candidates,
   summarized tail, padded resumes caught with reasons.
3. The entire V2 delta exists as git history in this folder; no Agentforce Builder assistant
   usage; UI touched only for preview (or not at all if CLI testing works).
4. Demo-test suite (flow assertions + agent tests or scripted ladder) runs green and is committed.
5. Build journal has a verdict for every docs lookup; POV brief + Artifact page finished.
