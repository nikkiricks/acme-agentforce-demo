// Data service for the Acme Agentic Experience — Board View app page.
// Altitude: Acme's OWN C-suite reporting to Acme's board on the one-quarter
// agentic-hiring mandate, across all ~400 enterprise customers — not the view
// a single customer sees (that clone lives in CustomerPipelineController).
// The LWC is a pure presentation layer bound to the typed contract below:
// getCandidateSideStats() is live CRM SOQL; getBoardMetrics() is a seeded
// insight layer that a Data Cloud / Tableau Next query can replace without
// touching the component.
public with sharing class AgenticExperienceBoardController {

    // The one REAL number on the board: this org is framed as one pilot
    // customer workspace, and this live count feeds the "+N live in this
    // workspace" badge on the platform-wide screenings tile. Same canonical
    // filter as scripts/verify-roster.sh, and WITH USER_MODE so the viewer
    // sees only what their own access allows — the same wall SecurityBeatTest
    // proves for a zero-permission user.
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

    // Enterprise logo retention by quarter. The Q3 dip is the story's
    // inciting incident — the Fortune 500 retailer logo lost to an
    // "AI-native" competitor — and the recovery tracks the agentic rollout.
    // Retention is quarterly by nature, so this tile deliberately does NOT
    // re-cut with the D/W/M toggle; its delta is always vs prior quarter.
    private static final List<Decimal> RETENTION_QUARTERS = new List<Decimal>{
        99.0, 98.4, 95.9, 96.2, 96.8
    };

    // Screening volume (thousands per period), aligned index-for-index with
    // the time-to-shortlist series above. The product-view chart shades this
    // behind the line: time-to-shortlist held flat while volume went ~5x.
    // End values tie out with the screenings tile (18.4K/day · 128K/wk · 552K/mo).
    private static final List<Decimal> DAILY_VOL = new List<Decimal>{
        17.2, 17.5, 17.1, 17.8, 17.6, 18.0, 17.9, 18.1, 17.8, 18.2, 18.0, 18.3, 18.1, 18.4
    };
    private static final List<Decimal> WEEKLY_VOL = new List<Decimal>{
        26, 34, 43, 55, 66, 78, 89, 99, 108, 116, 123, 128
    };
    private static final List<Decimal> MONTHLY_VOL = new List<Decimal>{
        92, 168, 264, 372, 468, 552
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

        List<Decimal> series =
            g == 'DAILY' ? DAILY_DAYS : (g == 'WEEKLY' ? WEEKLY_DAYS : MONTHLY_DAYS);
        m.trend = buildTrend(g, series);

        Integer lastQ = RETENTION_QUARTERS.size() - 1;
        Decimal retention = RETENTION_QUARTERS[lastQ];
        Decimal retentionChange =
            (retention - RETENTION_QUARTERS[lastQ - 1]).setScale(1);

        m.tiles = new List<KpiTile>{
            // The mandate-progress number: customers live on agentic screening.
            tile('customersLive', 'Customers live on agentic screening', '42 of 400',
                delta(g == 'DAILY' ? '1' : (g == 'WEEKLY' ? '4' : '11'), vsPrior, true)),
            // Platform-wide screenings; the LWC pins the live workspace badge here.
            tile('screenedPlatform', 'Candidates screened by agents',
                g == 'DAILY' ? '18.4K' : (g == 'WEEKLY' ? '128K' : '552K'),
                delta(g == 'DAILY' ? '5%' : (g == 'WEEKLY' ? '6%' : '19%'), vsPrior, true)),
            tile('logoRetention', 'Enterprise logo retention', retention.setScale(1) + '%',
                delta(retentionChange.abs() + ' pts', 'vs prior quarter', retentionChange > 0)),
            // 74% autonomous ties out with the pipeline strip: 33.3K flagged
            // of 128K screened = 26% escalated.
            tile('autonomousRate', 'Autonomous resolution rate', '74%',
                delta(g == 'DAILY' ? '1 pt' : (g == 'WEEKLY' ? '2 pts' : '4 pts'), vsPrior, true))
        };

        // Pipeline totals are period-independent on purpose: the strip is the
        // structural "two sides, one pipeline" proof, aggregated across all
        // live customers, and holding it stable while the toggle re-cuts
        // everything above keeps the eye on the flow.
        m.pipeline = new Pipeline();
        m.pipeline.clientSide = new List<PipelineStage>{
            stage('Open reqs', '860'), stage('Shortlists delivered', '512')
        };
        m.pipeline.candidateSide = new List<PipelineStage>{
            stage('Applications', '152K'), stage('Agent-screened', '128K'),
            stage('Flagged for review', '33.3K'), stage('Outreach sent', '43.7K')
        };
        m.pipeline.placements = 480;

        // The payload is a SUPERSET: every metric the component might render,
        // named by metric, never by audience. Which fields appear on screen is
        // the LWC's persona configuration — this service does not know
        // personas exist.
        m.activeRecruiters = tile('activeRecruiters',
            'Weekly active recruiters on agent screening', '1,340',
            delta(g == 'DAILY' ? '2%' : (g == 'WEEKLY' ? '5%' : '14%'), vsPrior, true));
        m.activeRecruiters.note = '68% of eligible seats';

        // Trending down but floored around ~5% by design: a 0% override rate
        // would read as "nobody is checking the agent," not as quality.
        m.overrideRate = tile('overrideRate', 'Recruiter override rate', '9.4%',
            delta(g == 'DAILY' ? '0.2 pts' : (g == 'WEEKLY' ? '0.5 pts' : '1.3 pts'),
                vsPrior, false));

        m.firstResponse = tile('firstResponse',
            'Median candidate first-response time', '11 min',
            delta(g == 'DAILY' ? '1 min' : (g == 'WEEKLY' ? '2 min' : '6 min'),
                vsPrior, false));
        m.firstResponse.note = 'pre-agent: 26 hrs';

        m.releaseVelocity = tile('releaseVelocity',
            'Spec → GA vs 12-wk board mandate ✓', '11 weeks', null);
        m.releaseVelocity.note = '4 releases since GA · 82% delivered via config';

        m.volume = g == 'DAILY' ? DAILY_VOL : (g == 'WEEKLY' ? WEEKLY_VOL : MONTHLY_VOL);
        m.volumeEndLabel =
            g == 'DAILY' ? '18.4K/day' : (g == 'WEEKLY' ? '128K/wk' : '552K/mo');

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

    private static PipelineStage stage(String label, String value) {
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
        @AuraEnabled public List<KpiTile> tiles;      // exactly 4
        @AuraEnabled public List<TrendPoint> trend;
        @AuraEnabled public Decimal baselineDays;
        @AuraEnabled public String baselineLabel;
        @AuraEnabled public Pipeline pipeline;
        // Superset metrics, named by metric — the LWC's persona configuration
        // decides which appear; this contract stays audience-agnostic.
        @AuraEnabled public KpiTile activeRecruiters;
        @AuraEnabled public KpiTile overrideRate;
        @AuraEnabled public KpiTile firstResponse;
        @AuraEnabled public KpiTile releaseVelocity;
        @AuraEnabled public List<Decimal> volume;     // aligned with trend
        @AuraEnabled public String volumeEndLabel;    // '128K/wk'
    }

    public class KpiTile {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String value;   // pre-formatted: '42 of 400', '128K', '96.8%'
        @AuraEnabled public KpiDelta delta; // null = no delta row (e.g. a met mandate)
        @AuraEnabled public String note;    // optional sub-line: '68% of eligible seats'
    }

    public class KpiDelta {
        @AuraEnabled public String amount;  // '0.6 pts', '6%', '4'
        @AuraEnabled public String label;   // 'vs prior week', 'vs prior quarter'
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
        @AuraEnabled public String value;   // pre-formatted platform-scale: '152K', '860'
    }
}
