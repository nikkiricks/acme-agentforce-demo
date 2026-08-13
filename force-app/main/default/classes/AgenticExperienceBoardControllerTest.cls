@IsTest
private class AgenticExperienceBoardControllerTest {

    // The live badge's query filters on Email LIKE '%example.com'. Inserting a
    // control Contact with a NON-matching email alongside the matching ones is
    // what makes this test non-vacuous: without the control, "count == 3"
    // would also pass if the filter matched every Contact in the database.
    @IsTest
    static void liveCountReflectsOnlyExampleDotComContacts() {
        insert new List<Contact>{
            new Contact(LastName = 'Screened1', Email = 'screened.one@example.com'),
            new Contact(LastName = 'Screened2', Email = 'screened.two@example.com'),
            new Contact(LastName = 'Screened3', Email = 'screened.three@example.com'),
            new Contact(LastName = 'Control', Email = 'not.a.candidate@other.invalid')
        };

        AgenticExperienceBoardController.CandidateSideStats stats =
            AgenticExperienceBoardController.getCandidateSideStats();

        // Tests run as the admin context user, so the controller's
        // WITH USER_MODE clause passes trivially here — the zero-permission
        // wall behind the same clause is what SecurityBeatTest proves.
        Assert.areEqual(3, stats.screenedCount,
            'Only example.com contacts should count as agent-screened');
        Assert.isTrue(stats.asOf != null, 'Last-refreshed timestamp should be stamped');
    }

    // Weekly is the dashboard default, so its contract is pinned tightest.
    // Lowercase input on purpose: the LWC sends 'WEEKLY' but the method
    // promises normalization, and this is where that promise is held.
    @IsTest
    static void weeklyMetricsHonorTheSeededContract() {
        AgenticExperienceBoardController.BoardMetrics m =
            AgenticExperienceBoardController.getBoardMetrics('weekly');

        Assert.areEqual('WEEKLY', m.granularity, 'Granularity should be normalized');
        Assert.areEqual(12, m.trend.size(), 'Weekly trend should span 12 weeks');
        Assert.areEqual(9.5, m.baselineDays, 'Pre-agent baseline anchors the chart');
        Assert.areEqual(3.2, m.trend[11].days, 'Current weekly time-to-shortlist');
        Assert.areEqual(4, m.tiles.size(), 'Exactly four board tiles');
        Assert.areEqual('42 of 400', m.tiles[0].value,
            'Mandate progress: customers live on agentic screening');
        Assert.areEqual('128K', m.tiles[1].value, 'Platform-wide weekly screenings');
        Assert.areEqual(2, m.pipeline.clientSide.size(), 'Client side: reqs and shortlists');
        Assert.areEqual(4, m.pipeline.candidateSide.size(),
            'Candidate side: applications through outreach');
        Assert.isTrue(m.pipeline.placements > 0, 'The two sides must meet at placements');
    }

    // The payload is a superset covering every persona the LWC can render;
    // the service itself is audience-agnostic. These are the product-view
    // fields, present at every granularity with a volume series that always
    // aligns index-for-index with the trend it shades.
    @IsTest
    static void supersetPayloadCoversTheProductMetrics() {
        for (String g : new List<String>{ 'DAILY', 'WEEKLY', 'MONTHLY' }) {
            AgenticExperienceBoardController.BoardMetrics m =
                AgenticExperienceBoardController.getBoardMetrics(g);
            Assert.areEqual('1,340', m.activeRecruiters.value,
                'Weekly active recruiters at granularity ' + g);
            Assert.areEqual('68% of eligible seats', m.activeRecruiters.note,
                'Adoption note rides the recruiters tile');
            // Floor check: the override rate trends down but must never read
            // as ~0% — a 0% override rate means nobody is checking the agent.
            Assert.areEqual('9.4%', m.overrideRate.value, 'Override rate value');
            Assert.isTrue(m.overrideRate.value.startsWith('9'),
                'Override rate stays well above the ~5% floor');
            Assert.isTrue(!m.overrideRate.delta.up, 'Override rate trends down');
            Assert.areEqual('11 min', m.firstResponse.value, 'First-response time');
            Assert.areEqual('pre-agent: 26 hrs', m.firstResponse.note,
                'First-response tile carries the pre-agent comparison');
            Assert.areEqual('11 weeks', m.releaseVelocity.value, 'Spec-to-GA velocity');
            Assert.isTrue(m.releaseVelocity.delta == null,
                'A met mandate has no delta row');
            Assert.isTrue(m.releaseVelocity.note.contains('82%'),
                'Velocity note carries the config-vs-code split');
            Assert.areEqual(m.trend.size(), m.volume.size(),
                'Volume series aligns with the trend it shades at ' + g);
        }
        // The product chart's caption promises ~5x: weekly volume must back it.
        AgenticExperienceBoardController.BoardMetrics weekly =
            AgenticExperienceBoardController.getBoardMetrics('WEEKLY');
        Decimal first = weekly.volume[0];
        Decimal last = weekly.volume[weekly.volume.size() - 1];
        Assert.isTrue(last >= first * 4.5, 'Screening volume grew ~5x across the weekly series');
        Assert.areEqual('128K/wk', weekly.volumeEndLabel,
            'Volume end label ties out with the screenings tile');
    }

    // Retention is Acme's own enterprise-logo churn story: the seeded series
    // dips the quarter the Fortune 500 retailer left, then recovers with the
    // agentic rollout. Quarterly by nature — the tile must NOT re-cut with
    // the D/W/M toggle, so its delta label is pinned to 'vs prior quarter'
    // at every granularity.
    @IsTest
    static void logoRetentionIsQuarterlyAndRecovering() {
        for (String g : new List<String>{ 'DAILY', 'WEEKLY', 'MONTHLY' }) {
            AgenticExperienceBoardController.BoardMetrics m =
                AgenticExperienceBoardController.getBoardMetrics(g);
            AgenticExperienceBoardController.KpiTile retention = m.tiles[2];
            Assert.areEqual('logoRetention', retention.key,
                'Retention holds the third tile slot at granularity ' + g);
            Assert.areEqual('96.8%', retention.value,
                'Retention value is quarterly and toggle-independent');
            Assert.areEqual('vs prior quarter', retention.delta.label,
                'Retention delta always compares quarters');
            Assert.isTrue(retention.delta.up, 'Retention should be recovering');
        }
    }

    // The whole point of the seed is a story that trends the right way at
    // every granularity — down for time-to-shortlist, believable (70s%,
    // never 99%) for autonomous resolution.
    @IsTest
    static void dailyAndMonthlySeriesHaveExpectedShape() {
        AgenticExperienceBoardController.BoardMetrics daily =
            AgenticExperienceBoardController.getBoardMetrics('DAILY');
        AgenticExperienceBoardController.BoardMetrics monthly =
            AgenticExperienceBoardController.getBoardMetrics('MONTHLY');

        Assert.areEqual(14, daily.trend.size(), 'Daily trend should span 14 days');
        Assert.areEqual(6, monthly.trend.size(), 'Monthly trend should span 6 months');
        Assert.isTrue(monthly.trend[0].days > monthly.trend[5].days,
            'Time-to-shortlist must trend down across the monthly series');
        for (AgenticExperienceBoardController.KpiTile t : monthly.tiles) {
            if (t.key == 'autonomousRate') {
                Assert.isTrue(t.value.startsWith('7'),
                    'Autonomous resolution should sit in the believable 70s');
            }
        }
    }

    // Bad input fails loudly instead of silently defaulting — a wrong toggle
    // wiring in the LWC should surface during rehearsal, not on stage.
    @IsTest
    static void unknownGranularityThrows() {
        Boolean threw = false;
        try {
            AgenticExperienceBoardController.getBoardMetrics('QUARTERLY');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Assert.isTrue(threw, 'Unknown granularity should raise AuraHandledException');
    }
}
