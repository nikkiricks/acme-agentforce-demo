@IsTest
private class CustomerPipelineControllerTest {

    // The live tile's query filters on Email LIKE '%example.com'. Inserting a
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

        CustomerPipelineController.CandidateSideStats stats =
            CustomerPipelineController.getCandidateSideStats();

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
        CustomerPipelineController.BoardMetrics m =
            CustomerPipelineController.getBoardMetrics('weekly');

        Assert.areEqual('WEEKLY', m.granularity, 'Granularity should be normalized');
        Assert.areEqual(12, m.trend.size(), 'Weekly trend should span 12 weeks');
        Assert.areEqual(9.5, m.baselineDays, 'Pre-agent baseline anchors the chart');
        Assert.areEqual(3.2, m.trend[11].days, 'Current weekly time-to-shortlist');
        Assert.areEqual(3, m.tiles.size(), 'Exactly three seeded tiles beside the live one');
        Assert.areEqual(2, m.pipeline.clientSide.size(), 'Client side: reqs and shortlists');
        Assert.areEqual(4, m.pipeline.candidateSide.size(),
            'Candidate side: applications through outreach');
        Assert.isTrue(m.pipeline.placements > 0, 'The two sides must meet at placements');
    }

    // The whole point of the seed is a story that trends the right way at
    // every granularity — down for time-to-shortlist, believable (70s–80s%,
    // never 99%) for autonomous resolution.
    @IsTest
    static void dailyAndMonthlySeriesHaveExpectedShape() {
        CustomerPipelineController.BoardMetrics daily =
            CustomerPipelineController.getBoardMetrics('DAILY');
        CustomerPipelineController.BoardMetrics monthly =
            CustomerPipelineController.getBoardMetrics('MONTHLY');

        Assert.areEqual(14, daily.trend.size(), 'Daily trend should span 14 days');
        Assert.areEqual(6, monthly.trend.size(), 'Monthly trend should span 6 months');
        Assert.isTrue(monthly.trend[0].days > monthly.trend[5].days,
            'Time-to-shortlist must trend down across the monthly series');
        for (CustomerPipelineController.KpiTile t : monthly.tiles) {
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
            CustomerPipelineController.getBoardMetrics('QUARTERLY');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Assert.isTrue(threw, 'Unknown granularity should raise AuraHandledException');
    }
}
