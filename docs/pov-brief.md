# Acme Enterprise — a CLI-First Agentforce PoC

A point of view, backed by a build. Everything below is verifiable in this repo
or in the org; nothing is aspirational.

**Published one-page version:**
https://claude.ai/code/artifact/3cfe5d8f-0162-40fa-bd37-af7f2df08625
(source `docs/pov-artifact.html`). Runbook for the live demo:
`docs/demo-runbook.md`.

---

## 1. The customer constraint

Acme Enterprise runs regulated hiring at scale. A single requisition draws
hundreds of applicants, and every screening decision is a decision a regulator,
a works council, or a plaintiff's attorney can ask about two years later.

That produces a hard constraint that most AI screening demos quietly ignore:
**Acme cannot adopt AI screening unless it is governed and auditable.** Not
"explainable" in the marketing sense — auditable in the boring sense. Which
version of the screener ran. What instructions it had that day. What data it
could see and who granted that access. What it actually did, step by step.

Any PoC that cannot answer those four questions is a science project, however
good the output looks on screen.

---

## 2. Point of view: the governed path is also the fast path

The reflexive assumption is that governance is a tax you pay after the demo —
build it fast in the UI, harden it later for the auditors. This build is the
argument against that.

**The whole agent lifecycle already lives in source control.** Author the agent
as an Agent Script file, validate it locally, publish it, activate it, test it —
every step is a `sf` command, and every step's input is a file you can diff,
review, and revert. The screening instructions, the flow-backed actions, the
run context, the data grants, and the test suite are all text in one repo.

Once that is true, the audit questions stop being an investigation and become a
`git log`. And the same property that satisfies the auditor — nothing changes
without a reviewable diff — is what makes the build fast, because nothing is
ever silently lost or half-applied.

**The UI is a preview window, not the workbench.** It is genuinely good for
watching an agent reason and for showing a customer the trace. It is the wrong
place to *hold* the work.

This is not a theory. This build's V1 was done entirely in the Agentforce
Builder UI on Aug 10. When V2 opened the org from the CLI, both prior
BotVersions were `Inactive` and the `CountCandidates` action that had been
demoed working in preview did not exist as committed metadata anywhere in the
org — zero `GenAiFunctionDefinition` records. **A working demo had been built
and then silently lost**, with no error, no warning, and no way to tell from the
UI. That is the failure mode source control makes structurally impossible, and
it is the strongest single argument in this deck.

---

## 3. Evidence: every V1 failure mode and its CLI antidote

Each row is a real problem hit while building V1 in the UI, and the specific
V2 mechanism that removes it. The artifact column is where to look in this repo.

| V1 failure mode (UI) | V2 CLI antidote | Artifact |
|---|---|---|
| **Assistant amnesia** — the authoring assistant lost all context on every new draft, timeout, or crash (~5 times in one session); every instruction had to be restated in full | Git history. The agent definition is a file; its state is the diff, not a chat transcript. Nothing to re-explain | `git log --oneline`; commit `765dc08` |
| **Silently half-applied edits** — assistant edits had to be manually verified in the `</>` code view because they were sometimes missed or partially applied | You edit the file. There is no intermediary to second-guess; `git diff` is the verification | `force-app/main/default/aiAuthoringBundles/Acme_Enterprise/Acme_Enterprise.agent` |
| **Hallucinated syntax** — the assistant invented `retriever://` targets and a `source:` attribute that do not exist, then proposed fixes for its own invention across three error cycles | `sf agent validate authoring-bundle` compiles the script locally against the real grammar before anything touches the org, and the diff is reviewed by a human first | `docs/build-journal.md`, Task 1 and Task 5 validate rows (`{"success": true}` first attempt, both actions) |
| **Parser-derailing syntax** — a `with` line inside an action *definition* block produced a phantom "must specify at least one input" error | Same validate step, plus a diff that shows the `actions:` definition block and the `reasoning.actions` reference block adjacent and reviewable | `git show 765dc08 -M -- '*aiAuthoringBundles*'` |
| **Edited-but-inactive flow** — an edited flow version that was never activated meant the old version stayed live; cost roughly an hour of debugging the wrong layer | `<status>Active</status>` is declared in the flow XML and deployed as source. Activation is not a click you can forget; it is a line in the file | `force-app/main/default/flows/Get_Candidate_Profiles.flow-meta.xml:70` |
| **Run-context mystery** — the count returned 0 for the agent but 8 in Debug. Two suspects were identified, one fix was applied, and *which one worked was never determined* | `<runInMode>SystemModeWithoutSharing</runInMode>` — one reviewable line, in source, in the diff. The grant is deliberate and legible, not discovered by elimination | `force-app/main/default/flows/Count_Candidates.flow-meta.xml:61` |
| **Import Wizard mis-mapping** — the wizard auto-mapped the resume text to *Account*: Description rather than Contact: Description, silently producing a roster with no resumes | Bulk API import from a CSV whose header row *is* the field mapping, plus a verification script that asserts the round-trip | `data/candidates-v2.csv`; `scripts/verify-roster.sh` |
| **Untestable demo** — "reset the simulator, retype the utterance, eyeball the answer," repeated after every config change, with stale sessions silently testing old config | `sf agent test` suite: 5 cases, versioned as YAML, run from one command, scored on topic, action, and an LLM judge. Case 5 is a bug a user hit in live preview, turned into a permanent regression test | `tests/agent/acme-triage-testspec.yaml`; `docs/demo-tests.md` |
| **Work lost entirely** — the Aug 10 UI session's committed-looking work was never persisted; both BotVersions `Inactive`, the action absent from the org | Immutable commits, then explicit `sf agent publish authoring-bundle` + `sf agent activate`. BotVersion 7 is `Active` in the org and byte-identical to what is in the repo | `docs/build-journal.md`, Task 2 version-state row and Task 5 publish/activate rows |

**The Agentforce Builder UI and its authoring assistant were never opened during
this build.** The entire V2 delta — roster, two flows, two agent actions, the
published and activated agent, the test suite, the security test — exists as
git history, produced from a terminal.

---

## 4. Docs scorecard — the honest version

I scored Salesforce's "robust documentation" claim live while building, logging
every question I had to ask of the docs and whether they answered it. Full
detail with commands and error text in `docs/build-journal.md`.

**33 questions across 9 tasks:**

| Verdict | Count |
|---|---|
| **answered** — docs solved it | 17 (52%) |
| **partial** — docs plus trial-and-error | 4 (12%) |
| **failed** — docs wrong, absent, or misleading | 10 (30%) |
| **failed, then answered** — docs sent me the wrong way, the org corrected them | 2 (6%) |

Two of the ten failures are not really Salesforce's: one was a local
`FORCE_COLOR` shell quirk, one was a defect in this build's own plan caught by
code review. **Eight hard documentation failures remain, and all eight are on
the `sf agent` / `AiAuthoringBundle` surface.**

| Surface | Rows | answered | partial | failed |
|---|---|---|---|---|
| `sf agent` + `AiAuthoringBundle` | 25 | 12 | 3 | 8 (+2 hybrid) |
| Flows, Bulk API, Apex | 8 | 5 | 1 | 2 (neither a real docs gap) |

**Best moment:** `sf agent test`. All four commands describe the full lifecycle
in their own `--help` and cross-reference each other by name, so reading one
tells you the next command to run. The newest surface in the build has its best
docs — which complicates the easy "new means undocumented" narrative. Even
there, though, `test results --help` documents a `--use-most-recent` flag in its
own examples that the shipped command rejects as nonexistent.

**Worst moment:** `sf agent publish authoring-bundle` and `sf agent test run
--wait` both **exit non-zero with `fetch failed` on runs that fully succeeded**.
The publish that reported failure had created BotVersion 3, registered both
function definitions, and logged a `Succeeded` deploy — provable only by taking
the deploy ID out of the *error* payload and cross-querying the org. An exit
code that lies is worse than a missing flag, because CI is built to trust
exactly that signal.

**The same pattern, one layer deeper — and the costliest finding in the build.**
Fixing a routing bug in Task 9 meant editing the router's instructions,
publishing, activating, and testing. `publish` and `activate` both reported
success the instant their metadata deploy landed, but the classifier model
behind the router took several more minutes to actually honor the change: four
consecutive publish-activate-test cycles reproduced the original bug before a
fifth attempt — no new publish, just elapsed time — finally passed. Nothing in
any command's output distinguishes "activated" from "the router now reflects
your edit." Four rounds of the fix were chased before the real variable turned
out to be the clock.

**Runner-up, and worse for a newcomer:** the CLI's own interactive
`generate test-spec` wizard offers org-suffixed topic and action names that the
runtime evaluator can never match — it compares against short local developer
names. Following the tool's own suggestions builds a permanently-failing test
suite. Found by reading the installed plugin's source.

**Four other findings worth carrying into any customer conversation:**
`AiAuthoringBundle` cannot be retrieved or deployed through the Metadata API at
any API version this org supports (`sf agent publish` is the only working path);
the bundle's folder name must equal the `developer_name` compiled from inside
the `.agent` file, and `-n/--api-name` is ignored for that lookup; the agent
test spec's `description` field has an undocumented 255-character server-side
cap that fails with `data value too large`; and Bulk API CSV line-ending
auto-detection misfires on CRLF, requiring an explicit `--line-ending CRLF`.

None of these are reasons not to build this way. They are the reasons a customer
wants a partner who has already hit them.

---

## 5. Security findings

The security story is not a slide; it is a test that runs.

**Zero data by default, proven non-vacuously.** `SecurityBeatTest` inserts a
candidate Contact, asserts the admin can see it (a positive control), then runs
as a freshly created `Minimum Access - Salesforce` user and asserts that
specific record is invisible. 2/2 pass, run `707bm000018WaZv`.

That second half matters more than the result. **The first version of this test
was vacuous and passed anyway** — without `SeeAllData`, an Apex test sees no
pre-existing records for *any* user, admin included, so "the bare user sees
nothing" was true by construction. It would have passed identically if the
minimum-access profile had full Contact read. A code review caught it; no
documentation would have. That is the exact failure mode this whole PoC is
arguing about: a green check that proves nothing, and the review discipline that
catches it. It is in the journal as a failure, not scrubbed out.

**Deliberate, declared grants.** The agent reads the roster because
`<runInMode>SystemModeWithoutSharing</runInMode>` is one line in the flow XML,
in the diff, in the review. The org itself flags it — the deploy returned an
`Info`-level warning that this mode grants view/edit on all data to running
users. Expected, intentional, and on the record. Contrast the V1 experience,
where the same grant was applied through a UI menu and nobody could later
determine whether it was the fix that worked.

**Immutable, committed versions.** BotVersion 7 is `Active`; v1 through v6
remain `Inactive`. Only one version can be active at a time. The active version's
source is in this repo, and publishing a new one is an explicit command that
leaves a commit behind.

**The decoy-user catch.** The agent's `default_agent_user` is locked after first
publish, and this org contains a near-twin user differing only in the numeric
suffix. During V1, an assistant edit swapped to the decoy and broke validation.
In V2 the `access:` block is a line in a file that no tool rewrites, and any
change to it appears in a diff — verified byte-for-byte unchanged across the
entire V2 delta.

---

## 6. The art of the possible

Everything above is a working PoC on a Developer Edition org, built in a day.
The interesting conversation is what comes next, and each of these is an
increment on machinery that already works, not a rebuild.

- **Auto-screen on arrival.** A record-triggered flow fires the same screening
  topic the moment an application lands, so the recruiter opens a triaged queue
  instead of an inbox — the agent is already invoked by flow; only the trigger
  changes.
- **Candidate-facing agent.** The same governed pattern, pointed outward:
  status, scheduling, and follow-up questions, with the never-auto-reject rule
  and the equitable-treatment rule enforced by the same instructions the
  recruiter's agent uses.
- **ATS integration.** Today the job requisition is pasted in. In production it
  arrives from the ATS, and the screening result posts back — the profile text
  already flows through a declared flow interface, which is where the connector
  attaches.
- **AgentExchange.** A regulated-hiring screening agent, packaged with its
  flows, permission model, and its test suite, distributed to the partner
  ecosystem — the tests travel with it, so the buyer can verify governance
  before installing rather than trusting a demo.

---

## 7. What I would tell Acme

You do not have to choose between shipping fast and shipping something you can
defend to a regulator. The evidence in section 3 is that the UI path cost me a
lost build, an hour on an inactive flow version, a data import that silently
mapped resumes onto the wrong object, and a root cause I never confirmed —
while the CLI path produced a live, activated, tested agent with a complete
audit trail and a scorecard honest enough to include its own failures.

The wiring is the product. Governance is not the tax on the demo; it is what
makes the demo mean something.
