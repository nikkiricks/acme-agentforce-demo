# Demo tests — the triage ladder as a repeatable suite

The 4-question demo ladder, expressed as a CLI-runnable Agentforce agent test
suite (`AiEvaluationDefinition`, "testing-center" runner) instead of a
click-through-and-eyeball manual script. Spec source of truth:
`tests/agent/acme-triage-testspec.yaml`. Deployed metadata:
`force-app/main/default/aiEvaluationDefinitions/Acme_Enterprise_Triage_Ladder.aiEvaluationDefinition-meta.xml`.

## Agent under test

- Bot: `Acme_Enterprise` (label "Acme Enterprise"), live on BotVersion 3.
- Topic exercised: `candidate_screening`. The org's full/suffixed
  `GenAiPluginDefinition` developer name is `candidate_screening_16jbm000002K4hR`
  (confirmed live via Tooling API query, not guessed) — but the test
  framework's runtime `topic_sequence_match`/`action_sequence_match`
  assertions actually compare against the **short** local developer name, not
  the full/suffixed one. The spec below uses the short names; see "Iteration
  note" further down and journal row 6 for how that was discovered.
- Actions exercised: `CountCandidates` (flow://Count_Candidates →
  `candidateCount`), `GetCandidateProfiles` (flow://Get_Candidate_Profiles →
  `profilesText`) — full org names `CountCandidates_179bm000003tC5I` /
  `GetCandidateProfiles_179bm000003tC5I`, same short-vs-full caveat as above.

## How to run

```bash
export FORCE_COLOR=0   # this shell has FORCE_COLOR=3 set globally, which corrupts `sf --json` output

# One-time: create/deploy the test definition from the spec (re-run with
# --force-overwrite any time tests/agent/acme-triage-testspec.yaml changes)
sf agent test create \
  --spec tests/agent/acme-triage-testspec.yaml \
  --api-name Acme_Enterprise_Triage_Ladder \
  --force-overwrite \
  -o renewal-org

# Run the suite and wait for results
sf agent test run \
  --api-name Acme_Enterprise_Triage_Ladder \
  -o renewal-org \
  --wait 10 \
  --verbose

# Re-fetch results for a prior run by job ID. `-i/--job-id` is REQUIRED —
# `sf agent test results --help` shows a `--use-most-recent` flag in its own
# examples, but that flag does not exist in this CLI version (2.145.6) and
# errors with "Nonexistent flag". See journal row 8.
sf agent test results --job-id <JOB_ID> -o renewal-org --verbose
```

Each test case is judged on three kinds of expectations:
- `topic_sequence_match` — did the run land in `candidate_screening`.
- `action_sequence_match` — did the expected flow-backed action(s) fire.
- `bot_response_rating` — an **LLM-judge scorer** (`grade: LLM_PASS_FAIL` in
  the framework's own scorer catalog) against a natural-language
  `expectedOutcome` description. This is the framework's semantic/judge
  expectation type, used here per the brief's guidance for cases whose
  output legitimately varies — including the ladder's concrete
  "response must literally contain X" requirements (the number 25, named
  candidates, the ⚠ character, padded-resume names), which are phrased
  directly into the `expectedOutcome` text rather than as separate
  `customEvaluations`. A `customEvaluations` (`string_comparison`,
  `operator: contains`) attempt for these was tried first and dropped — its
  `actual: $.generatedData.outcome` JSONPath reference errored server-side
  on every case. See "Iteration note" below and journal row 6.

## The 4 ladder cases

### 1. Candidate count
- **Utterance:** "How many candidates have applied?"
- **Expected:** topic `candidate_screening`; action `CountCandidates`
  invoked; response contains `25`.

### 2. Roster lookup by role
- **Utterance:** "Who has applied to the Senior Full-Stack Engineer role?"
- **Expected:** topic `candidate_screening`; action `GetCandidateProfiles`
  invoked; response names at least 3 of: Elena Vasquez, Maria Gonzalez,
  Marcus Chen.

### 3. Full screening against a rubric
- **Utterance:** "Screen all candidates on file for: Senior Full-Stack
  Engineer, Northwind logistics platform. Requirements: 5+ years,
  React/TypeScript, Node services, AWS."
- **Expected:** topic `candidate_screening`; action `GetCandidateProfiles`
  invoked; response is a ranked top-5 with rationale, includes at least one
  ⚠ human-review flag, and calls out at least one AI-padded resume among
  Tyler Brooks, Chloe Nakamura, or Viktor Petrov.

### 4. Outreach email
- **Utterance:** "Draft a short outreach email to the strongest candidate."
- **Setup:** run as a continuation (via `conversationHistory` in the spec) of
  case 3's screening result, so "the strongest candidate" resolves to a named
  person instead of nothing.
- **Expected:** response is an email naming Elena Vasquez or Maria Gonzalez.

## Last run — 2026-08-11

Job ID `4KBbm00000032tJGAQ`, run via `sf agent test run --api-name
Acme_Enterprise_Triage_Ladder -o renewal-org --wait 10 --verbose`. Completed
clean (`Status: COMPLETED`, no CLI errors) in 21s.

| Case | Utterance | Topic | Action | Outcome (LLM judge) | Overall |
|---|---|---|---|---|---|
| 1 | How many candidates have applied? | Pass | Pass (`CountCandidates`) | **Pass** — "There are currently 25 candidates on file in the system." | **PASS** |
| 2 | Who has applied to the Senior Full-Stack Engineer role? | Pass | Pass (`GetCandidateProfiles`) | **Fail** — agent asked for the job description instead of naming candidates: "I have candidate profiles available, but I need the specific job description for the Senior Full-Stack Engineer role to complete a screening..." | **FAIL (outcome only)** |
| 3 | Screen all candidates on file for: Senior Full-Stack Engineer, Northwind logistics platform... | Pass | Pass (`GetCandidateProfiles`) | **Pass** — full ranked list led by Elena Vasquez (98/100), included ⚠ Needs Human Review flags (Derek Holt, Aisha Bello, Viktor Petrov, Liam O'Donnell, Fatima Al-Rashid), and explicitly called out "Tyler Brooks: Claimed skills not supported by work history (AI-padded)" and "Chloe Nakamura: Experience does not match claims (AI-padded)." | **PASS** |
| 4 | Draft a short outreach email to the strongest candidate. (continuation of case 3's context) | Pass | Pass (`[]`, none expected/invoked) | **Pass, borderline (score 3)** — email addressed "Hi Elena," and referenced the Senior Full-Stack Engineer / Northwind role, but the surname "Vasquez" never appears anywhere in the generated text — only the first name. The judge's own `metricExplainability` flags this: *"The bot's response drafts an outreach email but does not name either of the specified recipients (Elena Vasquez or Maria Gonzalez). It uses a placeholder name 'Elena' without the full name... This omission makes the response partially aligned but not fully meeting the requirement."* | **PASS (partial credit, not a clean full-name match)** |

**Aggregate:** Topic Pass 100% (4/4), Action Pass 100% (4/4), Outcome Pass 75%
(3/4, `PASS`/`FAIL` at the framework's own threshold). **3 of 4 cases pass
outcome; case 2 is a real product finding, not a test-authoring bug** — see
note below. Note that "pass" for case 4 is borderline, not clean: the judge
scored it 3 (out of 5) and its own explainability text says the response
never actually says "Vasquez," only the first name "Elena" — see the row
above and the finding below. A reader using this table as a demo rehearsal
script should not expect the agent to say the candidate's full name.

### Finding: case 2's failure is a genuine agent-behavior gap

When asked "Who has applied to the Senior Full-Stack Engineer role?" with no
further requirements given, the agent invokes `GetCandidateProfiles`
correctly (topic/action both pass) but then asks the user for a job
description instead of just listing who's on file for that role. It only
lists names/rankings once a full requirements rubric is provided (as in case
3). This is worth a prompt-tuning follow-up on `candidate_screening`'s
instructions if the demo needs case 2 answered directly — flagging here
rather than editing the agent, since fixing agent behavior is out of scope
for this task.

### Iteration note: first run had a spec-authoring bug, not an agent bug

The first attempt at this suite (job `4KBbm00000032rhGAA`) used the
org-suffixed `GenAiPluginDefinition`/`GenAiFunctionDefinition` full names
(e.g. `candidate_screening_16jbm000002K4hR`,
`CountCandidates_179bm000003tC5I`) for `expectedTopic`/`expectedActions` —
these are what `sf agent generate test-spec`'s interactive prompts would
have offered (they're read from `GenAiPlannerBundle.localTopicLinks` /
`localActionLinks`). The **runtime** planner response
(`lastExecution.topic` / `lastExecution.invokedActions[].function.name`)
reports the **short local developer name** instead (`candidate_screening`,
`CountCandidates`), so every topic/action assertion errored or failed. Fixed
by switching the spec to short names throughout; see journal row 6 for the
full writeup, including a second, unresolved gap (`customEvaluations` with a
`$.generatedData.outcome` JSONPath actual-reference errored server-side —
dropped in favor of the built-in LLM-judge `bot_response_rating`/
`expectedOutcome` scorer, which the brief explicitly allows for
variable-output cases).

## Manual fallback (no CLI test framework)

If `sf agent test` is ever unusable in this org/edition, the same 4 cases can
be run by hand through `sf agent preview`:

```bash
sf agent preview -n Acme_Enterprise -o renewal-org --use-live-actions
```

Then paste each of the 4 utterances above in order (case 4 right after case
3, in the same session, so the agent has "the strongest candidate" in
context) and eyeball the same pass criteria listed above. `sf agent preview`
does not require a separately linked client app for a published/activated
agent — `--api-name`/`-n` plus `--use-live-actions` is sufficient once a
BotVersion is Active (confirmed in this session).
