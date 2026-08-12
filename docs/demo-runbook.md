# Demo runbook — Acme Enterprise, CLI-first

The exact sequence to run live. Every command below was executed in this repo
against `renewal-org` on 2026-08-11 and works as written.

**Before anything:** `export FORCE_COLOR=0` in the demo shell. This machine sets
`FORCE_COLOR=3` globally, which makes `sf ... --json` emit ANSI escapes and
breaks any JSON parsing (`scripts/verify-roster.sh` already handles this
internally; nothing else does).

```bash
cd /Users/nikkiricks/salesforce_interview_app/acme_enterprise-agentic_hiring_platform-demo
export FORCE_COLOR=0
```

Terminal setup: large font, one window, no split panes, no editor open. The
terminal *is* the slide.

---

## Beat 1 — The build is the audit trail (~60s)

**Say:** "Acme's constraint is that AI screening has to be auditable. So before
I show you the agent, here is the audit trail — because it's the same thing as
the build."

```bash
git log --oneline -10
```

Point at: one commit per capability — roster import, flow, agent actions, test
suite, security test. "Every one of these is a reviewable diff. Nothing about
this agent exists anywhere except in this history."

Then the diff that matters:

```bash
git show ':/actions wired' -M -- '*aiAuthoringBundles*'
```

(`:/actions wired` finds the wiring commit by message text, so the command works in
this repo and in the standalone `acme-agentforce-demo` split, whose SHAs differ.)

**Say:** "This is the agent's brain, as a diff." Point at three things and move
on — do not read it aloud:
1. The `## Bulk Screening and Counting` instruction block — natural language
   policy, reviewable line by line.
2. The `actions:` definitions — `GetCandidateProfiles` → `flow://Get_Candidate_Profiles`,
   `CountCandidates` → `flow://Count_Candidates`.
3. The `reasoning.actions` references underneath. "Definition and reference are
   different blocks. Getting that wrong in the UI cost me a phantom error I
   couldn't diagnose. Here it's two adjacent hunks in a diff."

**The line to land:** "The Agentforce Builder UI was never opened for any of
this. Not once."

---

## Beat 2 — Real data, verified (~30s)

**Say:** "The roster is real CRM data, imported through the Bulk API — not a
wizard that guesses which column goes where."

```bash
bash scripts/verify-roster.sh
```

Expected output:

```
== Total example.com candidates (expect 25):
25
== Spot-check description round-trip (Elena Vasquez):
79 words
```

**Say:** "25 candidates, and the script asserts a real resume actually landed on
the Contact — the first time I did this in the UI, the wizard silently mapped
every resume onto the *Account* description instead. The import didn't fail. It
just produced a roster with no resumes in it."

---

## Beat 3 — Security is a test, not a slide (~45s)

```bash
sf apex run test --tests SecurityBeatTest -o renewal-org --result-format human --wait 10
```

Expected: `Outcome Passed`, `Tests Ran 2`, `Pass Rate 100%`. Takes ~30–60s
including compile; start talking while it runs.

**Say, over the run:** "Two tests. The first creates a brand-new user on the
`Minimum Access` profile and proves it cannot see a candidate record — zero data
by default. The second proves the agent *can* read the roster, and only because
of one declared line in the flow's XML."

```bash
grep -n "runInMode\|<status>" force-app/main/default/flows/Count_Candidates.flow-meta.xml
```

**Say:** "`SystemModeWithoutSharing`, and `status: Active`. Two lines. In the
diff, in the review. In the UI those are two menus in two different places, and
in my first build I could never determine which one had actually fixed the
problem."

**Optional, if the panel is technical — this is the strongest honesty beat:**
"The first version of this security test passed and proved nothing. Apex tests
see no pre-existing data for anyone, so 'the restricted user sees nothing' was
true by construction. Code review caught it; no documentation would have. It's
in the journal as a failure."

---

## Beat 4 — The ladder, as a repeatable suite (~2 min)

The demo ladder is a versioned test suite, not a script someone retypes.

```bash
cat tests/agent/acme-triage-testspec.yaml
```

**Say:** "Five utterances, versioned in the repo. Each is scored three ways: did
it land in the right topic, did it fire the right flow-backed action, and an
LLM judge against a written expectation."

```bash
sf agent test run --api-name Acme_Enterprise_Triage_Ladder -o renewal-org --wait 10
```

Last clean run (job `4KBbm00000033qzGAA`, 2026-08-12) completed in **29 seconds**:
**Topic 5/5, Action 4/5, Outcome 4/5** — cases 1, 3, 4, 5 fully green; case 2 red on
action + outcome (same standing finding, expressed one layer earlier). Realistic
expectation across runs: **Topic 5/5, Action 4–5/5, Outcome 3–4/5** — case 2 is always
red somewhere, and case 4's judge is volatile. Say the range, not a single number.

### The five utterances, verbatim, with expected beats

| # | Utterance | Expected beat |
|---|---|---|
| 1 | `How many candidates have applied?` | Topic `candidate_screening`, action `CountCandidates` fires, answer contains **25** — live from CRM |
| 2 | `Who has applied to the Senior Full-Stack Engineer role?` | Topic **passes**; the agent asks for a job description instead of listing names, so outcome **fails** and the action assertion fails on some runs too (it may not call the flow at all). Known finding, not a regression |
| 3 | `Screen all candidates on file for: Senior Full-Stack Engineer, Northwind logistics platform. Requirements: 5+ years, React/TypeScript, Node services, AWS.` | Ranked top-5 led by **Elena Vasquez (98/100)**, ⚠ human-review flags, and named AI-padded resumes (**Tyler Brooks**, **Chloe Nakamura**) |
| 4 | `Draft a short outreach email to the strongest candidate.` | Email addressed to **Elena** — note: first name only, judge score varies 2-5 run to run. Do not promise a full-name match |
| 5 | `Draft a short outreach email to Elena Vasquez.` | Cold start, no prior context — the Task 9 router-fix regression case. Topic `candidate_screening`, action `GetCandidateProfiles` fires, email names Elena Vasquez, grounded in her profile |

**Own case 2 out loud — do not skip past it.** "Four of five pass. Case two is
a real product finding: without a rubric the agent asks for the job description
instead of just listing who's on file. That's a prompt-tuning follow-up, and I'd
rather show you the suite that catches it than a demo where nobody would ever
know."

**The line to land:** "This is why I'd hand this to a customer. Not because it's
perfect — because when it isn't, one command tells you exactly where."

---

## Beat 5 — Close on the art of the possible (~45s)

Four increments, one line each — auto-screen on application arrival, a
candidate-facing agent, ATS integration, AgentExchange distribution. All are
increments on the machinery just demoed, not rebuilds. Full text in
`docs/pov-brief.md` §6.

**Close on:** "Governance isn't the tax you pay after the demo. It's what makes
the demo mean anything. And the governed path turned out to be the faster
one — the UI build got silently lost; this one is still here."

---

## Fallbacks

**Roster is wrong / data got reseeded.** **Check the count before re-importing.**
The import is a pure insert with no upsert key, so running it against a roster
that is already intact duplicates the 17 CSV rows and takes you to 42 — which
breaks beat 1 far worse than whatever you were trying to fix.

```bash
# 1. Look first. Only proceed if this is BELOW 25.
bash scripts/verify-roster.sh

# 2. Only if the count is short:
sf data import bulk --sobject Contact --file data/candidates-v2.csv \
  --line-ending CRLF --wait 10 -o renewal-org
bash scripts/verify-roster.sh
```

`--line-ending CRLF` is mandatory — the Bulk API's auto-detection guesses LF and
rejects the file. Note the CSV holds 17 rows; the 25-count assumes the 8
original Contacts are still present, so a clean re-import into an emptied org
lands at 17, not 25. If the count comes back 17, say the real number rather than
the scripted one. If it comes back above 25, you have duplicates — do **not**
import again; delete the extras or just say the real number.

**The agent misbehaves live, or the test run hangs.** Do not debug on camera.
Show the last known-good results and speak beat 4 from the table above:

```bash
sf agent test results --job-id 4KBbm00000033qzGAA -o renewal-org --verbose
```

`-i/--job-id` is required. `--use-most-recent` appears in the command's own help
examples but does not exist in this CLI version — it errors. Do not reach for it
live.

**`sf agent test run` exits with `fetch failed`.** This is a known spurious
error; the run usually succeeded. Grab the job ID from the error and re-fetch
with the command above. Same pattern as `sf agent publish`. **Never trust a
non-zero exit from these two commands without re-querying.**

**The test framework is unusable entirely.** Fall back to live preview and paste
the five utterances in order (case 4 immediately after case 3, same session, so
"the strongest candidate" has context; case 5 works cold, in any session):

```bash
sf agent preview -n Acme_Enterprise -o renewal-org --use-live-actions
```

`--use-live-actions` is not optional — without it, preview *simulates* the flow
calls with AI. Demoing mocked actions to a customer would be the worst possible
outcome of a governance pitch.

**Org is down / no screenshare at all.** The POV artifact page **is** the story.
It carries the evidence table, the honest docs scorecard, the security findings,
and the test results without needing a terminal. Have the URL in the chat window
before the call starts, and `docs/pov-brief.md` open as the long form.

> **https://claude.ai/code/artifact/3cfe5d8f-0162-40fa-bd37-af7f2df08625**
> (source: `docs/pov-artifact.html`; private until shared from the page's share menu)

---

## Night-before checklist

- [ ] **Record a screen capture of the full happy path.** Non-negotiable. Beats
      1–4 end to end, no narration needed — this is the fallback that survives a
      dead org, a dead network, and a dead laptop.
- [ ] `export FORCE_COLOR=0` confirmed in the demo shell profile.
- [ ] `bash scripts/verify-roster.sh` returns 25.
- [ ] `sf apex run test --tests SecurityBeatTest` returns 2/2.
- [ ] `sf agent test run --api-name Acme_Enterprise_Triage_Ladder --wait 10`
      returns Topic 5/5, Action 4–5/5, Outcome 3–4/5 (case 2 red is expected). Record the new job ID here and
      in the fallback command above.
- [ ] `sf data query -q "SELECT VersionNumber, Status FROM BotVersion WHERE BotDefinition.DeveloperName = 'Acme_Enterprise'"`
      shows **v7 Active**.
- [ ] Artifact URL pasted somewhere reachable without the terminal.
- [ ] Terminal font size raised; scrollback cleared; `git log --oneline -10`
      already scrolled to.
