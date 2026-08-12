# Acme Demo V2 — CLI-First Rebuild — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the Acme Enterprise screening agent to recruiter-grade bulk triage (25 candidates, no resume pasting) built entirely from source + `sf` CLI, with a repeatable demo-test suite, a staged security beat, a docs-quality build journal, and a POV brief demoable to Hemant.

**Architecture:** SFDX project in `acme_enterprise-agentic_hiring_platform-demo/`; retrieve the existing `Acme_Enterprise_2` AiAuthoringBundle and `Count_Candidates` flow as baseline; add data via Bulk API, a new autolaunched flow authored as XML, an Agent Script edit as a git diff, Apex-based flow/security tests, and `sf agent test` agent-level tests. UI is only a preview fallback.

**Tech Stack:** Salesforce CLI 2.145.6 (`sf agent`, `sf data`, `sf project`, `sf apex`), Agent Script (AiAuthoringBundle), Flow metadata XML, Apex tests, git.

## Global Constraints

- Org: `renewal-org` (`nikki.ricks.ed23f8f2dd0c@agentforce.com`). Agent bundle: `Acme_Enterprise_2`. Agent ID `0Xxbm0000035JrVCAU`.
- **NEVER modify the agent's `config:` block** — especially `default_agent_user: acme_enterprise@00dbm00000sdxie1462262666.ext` (a decoy near-twin ends `…1408795431.ext`). Every agent edit must pass a `git diff` check showing the config block untouched.
- Valid Agent Script action targets are ONLY `apex://`, `flow://`, `prompt://`. No `source:` attribute, no `retriever://`.
- Full action definitions live in the subagent `actions:` block (NO `with` lines there); `reasoning.actions` holds references only (`Name: @actions.Name` + optional `with`).
- All candidate emails end `@example.com` (the flows' filter is load-bearing).
- Salesforce UI may be used ONLY for agent preview, and only if CLI preview/test is blocked. No Agentforce Builder authoring assistant, ever.
- **Journal rule:** every time official Salesforce docs/help are consulted, append a row to `docs/build-journal.md`: `| task | question | doc used | verdict (answered/partial/failed) | note |`. Every task below has a journal step — it is not optional.
- Stop-building rule: if a task is blocked >30 min, journal it, apply its fallback, move on. The committed V1 agent is the safety net.
- All `sf` commands target `renewal-org` via `-o renewal-org` (or set it default in Task 1).

---

### Task 1: Scaffold SFDX project, retrieve baseline, start the journal

**Files:**
- Create: `sfdx-project.json`, `.gitignore`, `.forceignore`, `docs/build-journal.md`
- Create (via retrieve): `force-app/main/default/aiAuthoringBundles/Acme_Enterprise_2/*`, `force-app/main/default/flows/Count_Candidates.flow-meta.xml`

**Interfaces:**
- Produces: baseline source tree; all later tasks edit/deploy from `force-app/main/default/`. Journal file with table header that all tasks append to.

- [ ] **Step 1: Write project scaffold**

`sfdx-project.json`:
```json
{
  "packageDirectories": [{ "path": "force-app", "default": true }],
  "name": "acme-enterprise-demo",
  "namespace": "",
  "sfdcLoginUrl": "https://login.salesforce.com",
  "sourceApiVersion": "64.0"
}
```

`.gitignore`:
```
.sf/
.sfdx/
node_modules/
*.log
```

`.forceignore`:
```
**/jsconfig.json
**/.eslintrc.json
```

`docs/build-journal.md`:
```markdown
# V2 Build Journal — docs & platform findings

Scoring Salesforce's "robust docs" claim live during the CLI-first rebuild.
Verdicts: **answered** (docs solved it), **partial** (docs + trial-and-error), **failed** (docs wrong/absent).

| Task | Question I needed answered | Doc/source consulted | Verdict | Note |
|---|---|---|---|---|
```

- [ ] **Step 2: Set default org for the project**

Run: `sf config set target-org=renewal-org` (project-local)
Expected: confirmation table; `sf config get target-org` shows `renewal-org`.

- [ ] **Step 3: Retrieve the agent bundle and flow**

Run:
```bash
sf project retrieve start -m "AiAuthoringBundle:Acme_Enterprise_2" -m "Flow:Count_Candidates"
```
Expected: `Acme_Enterprise_2.agent` (+ `.bundle-meta.xml`) and `Count_Candidates.flow-meta.xml` under `force-app/main/default/`. If AiAuthoringBundle retrieve fails, retry with `-m "AiAuthoringBundle:Acme_Enterprise_2" --json` and journal the error; fallback is `sf agent generate authoring-bundle` (check `sf agent generate --help`) — journal whichever path worked.

- [ ] **Step 4: Validate the retrieved agent script locally**

Run: `sf agent validate --help` to get exact flags, then validate `force-app/main/default/aiAuthoringBundles/Acme_Enterprise_2/Acme_Enterprise_2.agent`.
Expected: validation passes (baseline is a working committed agent). If the command needs an org connection, note that in the journal.

- [ ] **Step 5: Read the retrieved `.agent` file fully**

Confirm presence of: `candidate_screening` subagent, `CountCandidates` action (target `flow://Count_Candidates`), screening instructions (score bands, ⚠ 60–75, never-reject, equitable-treatment), `default_agent_user` ending `1462262666.ext`. Record the exact structure of the `CountCandidates` definition + reference — Task 5 mirrors it verbatim.

- [ ] **Step 6: Journal + commit**

Append journal rows for any docs consulted (e.g., retrieve syntax for AiAuthoringBundle).
```bash
git add -A acme_enterprise-agentic_hiring_platform-demo
git commit -m "feat: V2 baseline — retrieve Acme agent + Count_Candidates as source"
```

### Task 2: Verify the agent's version state (handoff's unfinished task)

**Files:**
- Modify: `docs/build-journal.md`

**Interfaces:**
- Produces: a definitive answer (committed vs draft) recorded in the journal; Task 5 depends on knowing this (deploying over a draft vs a committed version behaves differently).

- [ ] **Step 1: Query agent version state from the CLI**

Try in order, journal which worked:
```bash
sf data query -q "SELECT DeveloperName, Id FROM BotDefinition WHERE DeveloperName LIKE 'Acme%'"
sf data query -q "SELECT BotDefinition.DeveloperName, VersionNumber, Status FROM BotVersion WHERE BotDefinition.DeveloperName LIKE 'Acme%' ORDER BY VersionNumber"
```
Expected: version rows with Status (e.g., `Active`/`Draft`/`Archived`). Interpretation: if the latest version's status shows the count+screening work is not in an active/committed version, note it — Task 5's deploy + `sf agent publish`/`activate` becomes the commit mechanism (check `sf agent publish --help` and `sf agent activate --help`).

- [ ] **Step 2: Journal the finding**

Record: could CLI answer "is the agent committed?" — verdict + the working query. This is journal finding #1 regardless of outcome.

- [ ] **Step 3: Commit**

```bash
git add acme_enterprise-agentic_hiring_platform-demo/docs/build-journal.md
git commit -m "docs: journal — agent version state verified via CLI"
```

### Task 3: 25-candidate roster via Bulk API

**Files:**
- Create: `data/candidates-v2.csv`, `scripts/verify-roster.sh`
- Modify: `docs/build-journal.md`

**Interfaces:**
- Produces: 25 Contacts in org with Email `…@example.com`, `Title`, and 60–80-word `Description` profiles. Tasks 4–6 assume exactly 25 and that Maria Gonzalez / Tom Becker exist by name.

- [ ] **Step 1: Query the existing 8 to avoid duplicates**

Run: `sf data query -q "SELECT FirstName, LastName, Email, Title FROM Contact WHERE Email LIKE '%example.com'" --json`
Expected: 8 rows (Maria Gonzalez, James Okafor, Tom Becker, Alex Rivera, Dana Liu, Sam Patel, Priya Sharma, Jordan Kim). If different, adjust the new-candidate list so the final total is 25 unique emails.

- [ ] **Step 2: Author `data/candidates-v2.csv` — 17 new candidates**

Columns: `FirstName,LastName,Email,Title,Description`. Emails `first.last@example.com` (must not collide with the existing 8). Each Description is a realistic 60–80-word recruiter-visible profile written from this archetype table (the target role is **Senior Full-Stack Engineer, Northwind logistics platform — React/TypeScript, Node, AWS, 5+ yrs**). RFC-4180 quoting: wrap every Description in double quotes; no newlines inside fields.

| Name | Title | Archetype | Facts the Description must support |
|---|---|---|---|
| Elena Vasquez | Staff Software Engineer | ⭐ star | 9 yrs; led React/TS platform rebuild at a freight startup; Node microservices on AWS ECS; mentors 4 engineers; logistics domain |
| Marcus Chen | Senior Frontend Engineer | borderline 60–75 | strong React/TS 6 yrs, but no backend/Node depth; AWS exposure limited to S3/CloudFront |
| Aisha Bello | Full-Stack Developer | borderline 60–75 | 4 yrs (just under bar); solid React+Node; only side-project AWS |
| Derek Holt | Senior Software Engineer | borderline 60–75 | 8 yrs Java/Spring; React only last 18 months; strong systems, thin TS |
| Ingrid Larsen | Senior Full-Stack Engineer | borderline 60–75 | 6 yrs agency work, many short projects; breadth over depth; unclear ownership |
| Tyler Brooks | Senior Full-Stack Engineer | 🚩 AI-padded | claims React, Vue, Angular, Node, Go, Rust, K8s, "AI/LLM engineering" — work history is 3 yrs WordPress agency |
| Chloe Nakamura | Lead Engineer | 🚩 AI-padded | claims "led 20-person org, drove $40M platform" — history shows 2 yrs junior QA then 1 yr bootcamp TA |
| Viktor Petrov | Senior Developer | 🚩 AI-padded | skills list is 30+ technologies incl. TS/React/AWS — every job bullet is generic ("worked on features, fixed bugs"), no shipped product named |
| Rosa Delgado | Registered Nurse | wrong role | 10 yrs ICU nursing; applying to "anything tech" after a coding bootcamp intro course |
| Ben Whitfield | Account Executive | wrong role | 7 yrs SaaS sales; no engineering history; "great with people, learns fast" |
| Grace Osei | Software Engineer II | middling | 3 yrs React, some Node; no AWS; solid but junior for the req |
| Liam O'Donnell | Backend Engineer | middling | 5 yrs Python/Django; minimal JS; strong SQL |
| Yuki Tanaka | Mobile Engineer | middling | 6 yrs React Native; web React adjacent; no Node services |
| Fatima Al-Rashid | DevOps Engineer | middling | 5 yrs AWS/Terraform strength; light application-code experience |
| Carlos Mendes | Full-Stack Engineer | middling | 5 yrs PHP/Laravel + Vue; React only via tutorials |
| Hannah Kim | Senior QA Engineer | middling | 8 yrs test automation in TS/Playwright; wants to transition to feature work |
| Omar Farouk | Solutions Architect | middling | 12 yrs enterprise integration; hands-off code for last 4 yrs |

- [ ] **Step 3: Import via Bulk API**

Run: `sf data import bulk --sobject Contact --file data/candidates-v2.csv --wait 10`
(If flag names differ in this CLI version, run `sf data import bulk --help` first and journal whether docs/help matched reality. Fallback: `sf data upsert bulk --sobject Contact --file data/candidates-v2.csv --external-id Id`-style is NOT needed for pure inserts — prefer import.)
Expected: 17 records processed, 0 failed.

- [ ] **Step 4: Write and run `scripts/verify-roster.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
echo "== Total example.com candidates (expect 25):"
sf data query -q "SELECT COUNT(Id) c FROM Contact WHERE Email LIKE '%example.com'" --json | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['records'][0]['c'])"
echo "== Spot-check description round-trip (Elena Vasquez):"
sf data query -q "SELECT Description FROM Contact WHERE Email = 'elena.vasquez@example.com'" --json | python3 -c "import sys,json; d=json.load(sys.stdin)['result']['records'][0]['Description']; print(len(d.split()), 'words'); assert 40 <= len(d.split()) <= 100"
```
Run: `bash scripts/verify-roster.sh`
Expected: `25` and a word count 60–80 with no assertion error.

- [ ] **Step 5: Journal + commit**

```bash
git add -A acme_enterprise-agentic_hiring_platform-demo
git commit -m "feat: 25-candidate triage roster imported via Bulk API"
```

### Task 4: `Get_Candidate_Profiles` flow — authored as XML, verified via Apex

**Files:**
- Create: `force-app/main/default/flows/Get_Candidate_Profiles.flow-meta.xml`, `scripts/apex/verify-profiles-flow.apex`
- Modify: `docs/build-journal.md`

**Interfaces:**
- Produces: active autolaunched flow `Get_Candidate_Profiles`; input `requestNote` (String); output `profilesText` (String) containing every candidate as `--- Name | Title | Email` + Description blocks. Task 5 targets `flow://Get_Candidate_Profiles` with exactly these variable names.

- [ ] **Step 1: Write the flow XML**

`force-app/main/default/flows/Get_Candidate_Profiles.flow-meta.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>64.0</apiVersion>
    <assignments>
        <name>Append_Profile</name>
        <label>Append Profile</label>
        <locationX>176</locationX>
        <locationY>431</locationY>
        <assignmentItems>
            <assignToReference>profilesText</assignToReference>
            <operator>Add</operator>
            <value>
                <elementReference>Profile_Line</elementReference>
            </value>
        </assignmentItems>
        <connector>
            <targetReference>Loop_Candidates</targetReference>
        </connector>
    </assignments>
    <environments>Default</environments>
    <interviewLabel>Get Candidate Profiles {!$Flow.CurrentDateTime}</interviewLabel>
    <label>Get Candidate Profiles</label>
    <loops>
        <name>Loop_Candidates</name>
        <label>Loop Candidates</label>
        <locationX>176</locationX>
        <locationY>323</locationY>
        <collectionReference>Get_Candidates</collectionReference>
        <iterationOrder>Asc</iterationOrder>
        <nextValueConnector>
            <targetReference>Append_Profile</targetReference>
        </nextValueConnector>
    </loops>
    <processMetadataValues>
        <name>BuilderType</name>
        <value>
            <stringValue>LightningFlowBuilder</stringValue>
        </value>
    </processMetadataValues>
    <processType>AutoLaunchedFlow</processType>
    <recordLookups>
        <name>Get_Candidates</name>
        <label>Get Candidates</label>
        <locationX>176</locationX>
        <locationY>215</locationY>
        <assignNullValuesIfNoRecordsFound>false</assignNullValuesIfNoRecordsFound>
        <connector>
            <targetReference>Loop_Candidates</targetReference>
        </connector>
        <filterLogic>and</filterLogic>
        <filters>
            <field>Email</field>
            <operator>Contains</operator>
            <value>
                <stringValue>example.com</stringValue>
            </value>
        </filters>
        <getFirstRecordOnly>false</getFirstRecordOnly>
        <object>Contact</object>
        <storeOutputAutomatically>true</storeOutputAutomatically>
    </recordLookups>
    <runInMode>SystemModeWithoutSharing</runInMode>
    <start>
        <locationX>50</locationX>
        <locationY>0</locationY>
        <connector>
            <targetReference>Get_Candidates</targetReference>
        </connector>
    </start>
    <status>Active</status>
    <textTemplates>
        <name>Profile_Line</name>
        <isViewedAsPlainText>true</isViewedAsPlainText>
        <text>--- {!Loop_Candidates.Name} | {!Loop_Candidates.Title} | {!Loop_Candidates.Email}
{!Loop_Candidates.Description}

</text>
    </textTemplates>
    <variables>
        <name>profilesText</name>
        <dataType>String</dataType>
        <isCollection>false</isCollection>
        <isInput>false</isInput>
        <isOutput>true</isOutput>
        <value>
            <stringValue></stringValue>
        </value>
    </variables>
    <variables>
        <name>requestNote</name>
        <dataType>String</dataType>
        <isCollection>false</isCollection>
        <isInput>true</isInput>
        <isOutput>false</isOutput>
    </variables>
</Flow>
```

- [ ] **Step 2: Deploy**

Run: `sf project deploy start -m "Flow:Get_Candidate_Profiles"`
Expected: Succeeded. If deploy errors on any element, journal the error + which doc resolved it (Flow metadata reference). Common trap: an empty `<value><stringValue/></value>` default on `profilesText` may need removal — if so, remove it, redeploy, journal.

- [ ] **Step 3: Write the Apex verification script**

`scripts/apex/verify-profiles-flow.apex`:
```apex
Map<String, Object> inputs = new Map<String, Object>{ 'requestNote' => 'verification run' };
Flow.Interview iv = Flow.Interview.createInterview('Get_Candidate_Profiles', inputs);
iv.start();
String profiles = (String) iv.getVariableValue('profilesText');
System.assert(profiles != null && profiles.length() > 0, 'profilesText empty');
Integer blocks = profiles.countMatches('--- ');
System.assert(blocks == 25, 'Expected 25 profile blocks, got ' + blocks);
System.assert(profiles.contains('Maria Gonzalez'), 'Missing existing candidate');
System.assert(profiles.contains('Elena Vasquez'), 'Missing new candidate');
System.debug('PROFILE BLOCKS: ' + blocks + ' | LENGTH: ' + profiles.length());
```

- [ ] **Step 4: Run it and verify**

Run: `sf apex run --file scripts/apex/verify-profiles-flow.apex`
Expected: success, debug line `PROFILE BLOCKS: 25`. If assertion fails on count, re-check roster (Task 3 verify) before touching the flow.

- [ ] **Step 5: Journal + commit**

```bash
git add -A acme_enterprise-agentic_hiring_platform-demo
git commit -m "feat: Get_Candidate_Profiles flow authored as XML, verified via Flow.Interview"
```

### Task 5: Wire the agent action — Agent Script diff, validate, deploy

**Files:**
- Modify: `force-app/main/default/aiAuthoringBundles/Acme_Enterprise_2/Acme_Enterprise_2.agent`
- Modify: `docs/build-journal.md`

**Interfaces:**
- Consumes: flow variable names from Task 4 (`requestNote` in, `profilesText` out); the exact `CountCandidates` block structure observed in Task 1 Step 5.
- Produces: `GetCandidateProfiles` action live on the agent; triage instructions active. Task 6's agent tests reference action name `GetCandidateProfiles` and subagent `candidate_screening`.

- [ ] **Step 1: Add the action definition**

In the `candidate_screening` subagent's `actions:` block, mirroring the retrieved `CountCandidates` block's exact indentation/typing style (if `CountCandidates` uses `object` + `complex_data_type_name` for inputs, copy that style):
```
        GetCandidateProfiles:
            description: "Returns the complete text profiles (name, title, email, resume summary) of every candidate on file in the CRM, for bulk screening. No resume pasting needed."
            inputs:
                requestNote: string
                    is_required: True
                    is_user_input: False
            outputs:
                profilesText: string
            target: "flow://Get_Candidate_Profiles"
```
NO `with` line inside this definition block (V1's phantom-error trap).

- [ ] **Step 2: Add the reference + instructions**

In `candidate_screening`'s `reasoning.actions`:
```
            GetCandidateProfiles: @actions.GetCandidateProfiles
                with requestNote = "recruiter bulk screening request"
```
In `candidate_screening`'s `reasoning.instructions`, append (adapted to the file's prose style):
```
If the recruiter asks to screen applicants on file, screen all applicants, or screen candidates without pasting resumes: call GetCandidateProfiles, then run the standard Screening Process on every returned profile. Give full scoring rationale for the top 5 candidates and for every candidate in the 60-75 human-review band; summarize all weaker fits in one short line each. Flag suspected AI-padded resumes (skill claims unsupported by work history) with the specific mismatch.
```

- [ ] **Step 3: Diff guard**

Run: `git diff -- force-app/main/default/aiAuthoringBundles/`
Expected: additions ONLY in `candidate_screening` blocks. The `config:` block (incl. `default_agent_user …1462262666.ext`) must show zero changes. If anything else changed, revert and redo.

- [ ] **Step 4: Validate locally, then deploy**

Run: `sf agent validate` with the bundle file (flags per Task 1 Step 4), then `sf project deploy start -m "AiAuthoringBundle:Acme_Enterprise_2"`
Expected: validation passes; deploy succeeds. On validation errors, remember V1 rule: if the error names an attribute you added beyond the template above, the attribute itself is the bug. Journal every error + resolving doc.

- [ ] **Step 5: Publish/activate if required**

If Task 2 showed deploys land in a draft, run `sf agent publish` / `sf agent activate` per their `--help` (journal: could the full author→publish loop stay in the CLI?).
Expected: agent's latest version live with the new action.

- [ ] **Step 6: Journal + commit**

```bash
git add -A acme_enterprise-agentic_hiring_platform-demo
git commit -m "feat: GetCandidateProfiles action wired into candidate_screening via Agent Script diff"
```

### Task 6: Demo tests — the ladder as a repeatable suite

**Files:**
- Create: `tests/agent/acme-triage-testspec.yaml` (exact path/format per `sf agent generate test-spec --help`), `docs/demo-tests.md`
- Modify: `docs/build-journal.md`

**Interfaces:**
- Consumes: action `GetCandidateProfiles`, subagent `candidate_screening`, roster of 25.
- Produces: runnable agent test suite + written ladder; Task 8's runbook references both.

- [ ] **Step 1: Explore the agent test workflow**

Run: `sf agent generate test-spec --help`, `sf agent test create --help`, `sf agent test run --help`, `sf agent test results --help`. Journal whether the docs/help make the workflow discoverable (this is the newest DX surface — the sharpest docs test in the build).

- [ ] **Step 2: Author the test spec (ladder as tests)**

Four cases (adapt keys to the generated spec format; content below is the source of truth):
1. utterance "How many candidates have applied?" → expected topic/subagent `candidate_screening`; expectation: response contains `25`.
2. utterance "Who has applied to the Senior Full-Stack Engineer role?" → expected action invoked includes `GetCandidateProfiles`; response mentions ≥3 known names (Elena Vasquez, Maria Gonzalez, Marcus Chen).
3. utterance "Screen all candidates on file for: Senior Full-Stack Engineer, Northwind logistics platform. Requirements: 5+ years, React/TypeScript, Node services, AWS." → expected action `GetCandidateProfiles`; response contains a top-5 with rationale, ⚠ human-review flags, and at least one padded-resume callout (Tyler Brooks, Chloe Nakamura, or Viktor Petrov).
4. utterance "Draft a short outreach email to the strongest candidate." → response is an email naming Elena Vasquez or Maria Gonzalez.

- [ ] **Step 3: Create + run the tests**

Run: `sf agent test create` (deploys the AiEvaluationDefinition), then `sf agent test run` with results wait, then inspect results.
Expected: suite runs; cases 1–2 pass cleanly; cases 3–4 judged by their contains-style expectations (LLM output varies — if the framework supports semantic/judge expectations, use those; journal it).
**Fallback** if `sf agent test` is unusable in this org/edition: journal the exact blocker, and make `docs/demo-tests.md` the scripted manual ladder instead (same 4 cases, with `sf agent preview` or Builder-preview steps and pass criteria).

- [ ] **Step 4: Write `docs/demo-tests.md`**

Regardless of path taken: the 4 ladder cases, how to run them (test run command or preview script), expected results, and last run's actual results with date.

- [ ] **Step 5: Journal + commit**

```bash
git add -A acme_enterprise-agentic_hiring_platform-demo
git commit -m "test: agent-level demo test suite for the triage ladder"
```

### Task 7: Security beat — zero-data-by-default as a runnable Apex test

**Files:**
- Create: `force-app/main/default/classes/SecurityBeatTest.cls`, `force-app/main/default/classes/SecurityBeatTest.cls-meta.xml`
- Modify: `docs/build-journal.md`

**Interfaces:**
- Produces: `sf apex run test --tests SecurityBeatTest` as a live demo command; Task 8's runbook and POV brief cite its two assertions.

- [ ] **Step 1: Write the test class**

`SecurityBeatTest.cls`:
```apex
@IsTest
private class SecurityBeatTest {

    // A brand-new user with no permission sets sees ZERO candidate data.
    // This is the platform's least-privilege default — the same wall the
    // agent user hit until access was deliberately granted.
    @IsTest
    static void newUserWithNoGrantsSeesNothing() {
        Profile minAccess = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        User bare = new User(
            Alias = 'zerop',
            Email = 'zero.priv@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'ZeroPriv',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = minAccess.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'zero.priv.' + System.currentTimeMillis() + '@example.invalid'
        );
        insert bare;

        System.runAs(bare) {
            Boolean blocked = false;
            try {
                List<Contact> visible = Database.query('SELECT Id FROM Contact WITH USER_MODE');
                blocked = visible.isEmpty();
            } catch (System.QueryException e) {
                blocked = true; // object-level access denied outright
            }
            Assert.isTrue(blocked, 'A no-permission user should see zero candidates');
        }
    }

    // The flow's declared run context (SystemModeWithoutSharing, one reviewable
    // line of XML) is the deliberate, auditable grant that lets the agent read
    // the roster.
    @IsTest
    static void declaredSystemContextSeesTheRoster() {
        Map<String, Object> inputs = new Map<String, Object>{ 'requestNote' => 'security beat' };
        Flow.Interview iv = Flow.Interview.createInterview('Get_Candidate_Profiles', inputs);
        iv.start();
        String profiles = (String) iv.getVariableValue('profilesText');
        Assert.isTrue(profiles != null && profiles.countMatches('--- ') > 0,
            'Flow in declared system context should return the roster');
    }
}
```

`SecurityBeatTest.cls-meta.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>64.0</apiVersion>
    <status>Active</status>
</ApexClass>
```
Note: the flow-interview test intentionally runs against org data (`@IsTest` without `SeeAllData` cannot see org Contacts — so annotate that method's class-level as needed). **Correction baked in:** use `@IsTest(SeeAllData=true)` on `declaredSystemContextSeesTheRoster` ONLY (method-level), keeping the zero-privilege test data-independent.

- [ ] **Step 2: Deploy and run**

Run:
```bash
sf project deploy start -m "ApexClass:SecurityBeatTest"
sf apex run test --tests SecurityBeatTest --result-format human --wait 10
```
Expected: 2/2 pass. If `Minimum Access - Salesforce` profile doesn't exist in this org, query `SELECT Name FROM Profile` and use the most restrictive standard profile; journal it.

- [ ] **Step 3: Journal + commit**

```bash
git add -A acme_enterprise-agentic_hiring_platform-demo
git commit -m "test: security beat — zero-data-by-default proven as runnable Apex test"
```

### Task 8: POV brief, Artifact page, demo runbook

**Files:**
- Create: `docs/pov-brief.md`, `docs/demo-runbook.md`
- Modify: `docs/build-journal.md` (final scorecard section)

**Interfaces:**
- Consumes: journal verdicts, test results, security beat output — all prior tasks.
- Produces: the Hemant screenshare artifact (published Artifact page) + the demo runbook.

- [ ] **Step 1: Finalize the journal scorecard**

Add a closing section to `docs/build-journal.md`: totals (answered/partial/failed), the single best doc moment, the single worst, and one sentence on whether "robust docs" held for the newest surfaces (`sf agent`) vs. the mature ones (flows, data).

- [ ] **Step 2: Write `docs/pov-brief.md`**

Structure (each bullet = a short section, written in Hemant's vocabulary — point of view, art of the possible, PoC):
1. **The customer constraint:** regulated hiring at scale; AI screening only if governed and auditable.
2. **Point of view:** the governed path is also the fast path — the whole agent lifecycle lives in source control; the UI is a preview window, not the workbench.
3. **Evidence table** — each V1 failure mode (handoff §2) → its V2 CLI antidote → artifact link: assistant amnesia → git history; hallucinated `retriever://` → `sf agent validate` locally + diff review; edited-but-inactive flow → `status=Active` in source; run-context mystery → `runInMode` declared in one reviewable XML line; Import Wizard mis-mapping → Bulk API CSV; untestable demo → `sf agent test` suite (or scripted ladder, per Task 6 outcome).
4. **Docs scorecard** (from journal) — honest, including failures.
5. **Security findings:** zero-data-by-default (SecurityBeatTest), deliberate declared grants, immutable committed versions, decoy-user validation catch.
6. **Art of the possible:** auto-screen on application arrival, candidate agent, ATS integration, AgentExchange — one line each.

- [ ] **Step 3: Publish the Artifact page**

Load the `artifact-design` skill first, then render the POV brief as a single-screen HTML artifact (title: "Acme Enterprise — a CLI-First Agentforce PoC"; favicon 🛠️). Keep it one scroll, evidence table + scorecard prominent, no marketing fluff.

- [ ] **Step 4: Write `docs/demo-runbook.md`**

Exact sequence: (1) terminal open — `git log --oneline` + the agent script diff; (2) `bash scripts/verify-roster.sh`; (3) `sf apex run test --tests SecurityBeatTest`; (4) agent test run or preview ladder — the 4 utterances verbatim with expected beats; (5) fallbacks (reseed = re-run Task 3 import; agent misbehaves = show test results + speak beat 4; no screenshare = POV artifact IS the story). Include the "record backup tonight" checklist item.

- [ ] **Step 5: Commit**

```bash
git add -A acme_enterprise-agentic_hiring_platform-demo
git commit -m "docs: POV brief, artifact page, demo runbook — V2 complete"
```

---

## Self-review notes

- Spec §1–§7 each map to Tasks 1–8 (spec §5 demo tests → Task 6 + flow verify in Task 4; spec §6 security beat → Task 7 with the runnable-test upgrade).
- Type/name consistency: `requestNote`/`profilesText` identical across flow XML (Task 4), Apex verify (Task 4), agent action (Task 5), security test (Task 7). Roster names in Task 3 match test expectations in Task 6 and Apex asserts in Task 4.
- Exploratory steps (`--help` probes) are deliberate: they ARE the docs test, and each carries a journal step + fallback.
