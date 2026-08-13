// Data service for the Agentic Experience — Board View app page.
// The LWC is a pure presentation layer bound to the typed contract below:
// getCandidateSideStats() is live CRM SOQL; getBoardMetrics() is a seeded
// insight layer that a Data Cloud / Tableau Next query can replace without
// touching the component.
public with sharing class AgenticExperienceBoardController {

    // The one REAL number on the board: candidates the agent screened, counted
    // live from CRM. Same canonical filter as scripts/verify-roster.sh, and
    // WITH USER_MODE so the viewer sees only what their own access allows —
    // the same wall SecurityBeatTest proves for a zero-permission user.
    @AuraEnabled(cacheable=true)
    public static CandidateSideStats getCandidateSideStats() {
        CandidateSideStats stats = new CandidateSideStats();
        stats.screenedCount = [
            SELECT COUNT() FROM Contact WHERE Email LIKE '%example.com' WITH USER_MODE
        ];
        stats.asOf = Datetime.now(); // stamped server-side at actual fetch time
        return stats;
    }

    @AuraEnabled(cacheable=true)
    public static BoardMetrics getBoardMetrics(String granularity) {
        String g = String.isBlank(granularity) ? 'WEEKLY' : granularity.toUpperCase();
        if (g != 'DAILY' && g != 'WEEKLY' && g != 'MONTHLY') {
            throw new AuraHandledException('Unknown granularity: ' + granularity);
        }
        return buildSeededMetrics(g);
    }

    // ---------------------------------------------------------------------
    // DEMO SEED — in production this method is swapped for a query against
    // Tableau Next / Data Cloud / CRM Analytics. The LWC contract does not change.
    // ---------------------------------------------------------------------
    // No randomness anywhere: every number lives in a fixed list so rehearsal
    // and the live run are identical. Date.today() touches axis LABELS only.
    //
    // Aggregation coherence: the mean of the daily series' last 7 points is
    // ~3.2, matching the last weekly point, and the weekly tail (~3.2–3.4)
    // matches the last monthly points — weekly reads as a rollup of daily and
    // monthly as a rollup of weekly, even though 12 weeks of history cannot
    // literally derive from 14 days of data.

    private static final Decimal BASELINE_DAYS = 9.5;

    private static final List<Decimal> DAILY_DAYS = new List<Decimal>{
        3.5, 3.4, 3.6, 3.3, 3.4, 3.2, 3.3, 3.1, 3.3, 3.2, 3.1, 3.2, 3.3, 3.2
    };
    private static final List<Decimal> WEEKLY_DAYS = new List<Decimal>{
        4.9, 4.6, 4.4, 4.1, 3.9, 3.8, 3.6, 3.5, 3.4, 3.3, 3.3, 3.2
    };
    private static final List<Decimal> MONTHLY_DAYS = new List<Decimal>{
        8.8, 7.1, 5.6, 4.4, 3.7, 3.4
    };

    // Fixed English month abbreviations — label text must not drift with the
    // org locale between rehearsal and the live run.
    private static final List<String> MONTHS = new List<String>{
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    };

    private static BoardMetrics buildSeededMetrics(String g) {
        BoardMetrics m = new BoardMetrics();
        m.granularity = g;
        m.baselineDays = BASELINE_DAYS;
        m.baselineLabel = 'pre-Agentforce: 9.5 days';

        String periodNoun = g == 'DAILY' ? 'day' : (g == 'WEEKLY' ? 'week' : 'month');
        String vsPrior = 'vs prior ' + periodNoun;

        // Seeded delta for the LIVE tile (the count itself comes from
        // getCandidateSideStats).
        m.screenedDelta = delta(
            g == 'DAILY' ? '3' : (g == 'WEEKLY' ? '9' : '21'), vsPrior, true);

        List<Decimal> series =
            g == 'DAILY' ? DAILY_DAYS : (g == 'WEEKLY' ? WEEKLY_DAYS : MONTHLY_DAYS);
        m.trend = buildTrend(g, series);

        Decimal current = series[series.size() - 1];
        Decimal prior = series[series.size() - 2];
        // One-decimal delta, direction from the series itself so tile and
        // chart can never disagree.
        Decimal change = (prior - current).setScale(1);

        m.tiles = new List<KpiTile>{
            tile('openRoles', 'Open client roles with a current shortlist', '34',
                delta(g == 'DAILY' ? '1' : (g == 'WEEKLY' ? '3' : '6'), vsPrior, true)),
            tile('timeToShortlist', 'Median time-to-shortlist', current.setScale(1) + ' days',
                delta(change.abs() + ' days', vsPrior, change < 0)),
            tile('autonomousRate', 'Autonomous resolution rate', '78%',
                delta(g == 'DAILY' ? '1 pt' : (g == 'WEEKLY' ? '2 pts' : '5 pts'), vsPrior, true))
        };

        // Pipeline totals are period-independent on purpose: the strip is the
        // structural "two sides, one pipeline" proof, and holding it stable
        // while the toggle re-cuts everything above keeps the eye on the flow.
        m.pipeline = new Pipeline();
        m.pipeline.clientSide = new List<PipelineStage>{
            stage('Open reqs', 34), stage('Shortlists delivered', 21)
        };
        m.pipeline.candidateSide = new List<PipelineStage>{
            stage('Applications', 412), stage('Agent-screened', 389),
            stage('Flagged for review', 57), stage('Outreach sent', 143)
        };
        m.pipeline.placements = 18;
        return m;
    }

    private static List<TrendPoint> buildTrend(String g, List<Decimal> series) {
        List<TrendPoint> points = new List<TrendPoint>();
        Date today = Date.today();
        Integer n = series.size();
        for (Integer i = 0; i < n; i++) {
            TrendPoint p = new TrendPoint();
            p.days = series[i];
            if (g == 'DAILY') {
                p.label = dayLabel(today.addDays(i - (n - 1)));
            } else if (g == 'WEEKLY') {
                p.label = dayLabel(today.addDays(7 * (i - (n - 1)))); // week ending
            } else {
                Date d = today.addMonths(i - (n - 1));
                p.label = MONTHS[d.month() - 1];
            }
            points.add(p);
        }
        return points;
    }

    private static String dayLabel(Date d) {
        return d.day() + ' ' + MONTHS[d.month() - 1];
    }

    private static KpiTile tile(String key, String label, String value, KpiDelta d) {
        KpiTile t = new KpiTile();
        t.key = key;
        t.label = label;
        t.value = value;
        t.delta = d;
        return t;
    }

    private static KpiDelta delta(String amount, String label, Boolean up) {
        KpiDelta d = new KpiDelta();
        d.amount = amount;
        d.label = label;
        d.up = up;
        return d;
    }

    private static PipelineStage stage(String label, Integer value) {
        PipelineStage s = new PipelineStage();
        s.label = label;
        s.value = value;
        return s;
    }

    // --- Typed contract shared by the seeded implementation today and a
    // --- Data Cloud / Tableau Next implementation tomorrow.

    public class CandidateSideStats {
        @AuraEnabled public Integer screenedCount;
        @AuraEnabled public Datetime asOf;
    }

    public class BoardMetrics {
        @AuraEnabled public String granularity;
        @AuraEnabled public KpiDelta screenedDelta;
        @AuraEnabled public List<KpiTile> tiles;
        @AuraEnabled public List<TrendPoint> trend;
        @AuraEnabled public Decimal baselineDays;
        @AuraEnabled public String baselineLabel;
        @AuraEnabled public Pipeline pipeline;
    }

    public class KpiTile {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String value;   // pre-formatted: '3.2 days', '78%', '34'
        @AuraEnabled public KpiDelta delta;
    }

    public class KpiDelta {
        @AuraEnabled public String amount;  // '0.1 days', '2 pts', '9'
        @AuraEnabled public String label;   // 'vs prior week'
        @AuraEnabled public Boolean up;     // arrow direction only, never color
    }

    public class TrendPoint {
        @AuraEnabled public String label;
        @AuraEnabled public Decimal days;
    }

    public class Pipeline {
        @AuraEnabled public List<PipelineStage> clientSide;
        @AuraEnabled public List<PipelineStage> candidateSide;
        @AuraEnabled public Integer placements;
    }

    public class PipelineStage {
        @AuraEnabled public String label;
        @AuraEnabled public Integer value;
    }
}
