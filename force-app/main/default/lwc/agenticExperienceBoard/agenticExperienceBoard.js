import { LightningElement, wire } from 'lwc';
import getCandidateSideStats from '@salesforce/apex/AgenticExperienceBoardController.getCandidateSideStats';
import getBoardMetrics from '@salesforce/apex/AgenticExperienceBoardController.getBoardMetrics';

// SVG chart geometry. Fixed y-domain 0–10.5 days so the 9.5 pre-agent
// baseline and the ~3.2 series always fit and the axis never rescales when
// the granularity toggles — a rescaling axis would visually lie about the trend.
const VIEW = { w: 600, h: 220, padL: 14, padR: 104, padT: 20, padB: 28 };
const Y_MAX = 10.5;

export default class AgenticExperienceBoard extends LightningElement {
    granularity = 'WEEKLY';

    @wire(getCandidateSideStats) candidateStats;
    // Reactive $granularity: toggling refetches; cacheable=true makes
    // toggling back instant from the client cache.
    @wire(getBoardMetrics, { granularity: '$granularity' }) board;

    handleGranularity(event) {
        this.granularity = event.target.dataset.granularity;
    }

    get hasError() {
        return Boolean(this.board.error || this.candidateStats.error);
    }
    get isLoading() {
        return !this.hasError && (!this.board.data || !this.candidateStats.data);
    }
    get isReady() {
        return Boolean(this.board.data && this.candidateStats.data);
    }

    get dailyVariant() {
        return this.granularity === 'DAILY' ? 'brand' : 'neutral';
    }
    get weeklyVariant() {
        return this.granularity === 'WEEKLY' ? 'brand' : 'neutral';
    }
    get monthlyVariant() {
        return this.granularity === 'MONTHLY' ? 'brand' : 'neutral';
    }

    get lastRefreshed() {
        return this.candidateStats.data?.asOf;
    }

    // The platform-wide screenings tile carries the one live number as a
    // badge: this org, framed as a single pilot customer workspace.
    get seededTiles() {
        const liveCount = this.candidateStats.data?.screenedCount;
        return (this.board.data?.tiles ?? []).map((t) => ({
            ...t,
            glyph: t.delta.up ? '▲' : '▼',
            deltaText: `${t.delta.amount} ${t.delta.label}`,
            liveBadge:
                t.key === 'screenedPlatform' && liveCount !== undefined
                    ? `+${liveCount} live in this workspace · LIVE FROM CRM`
                    : undefined
        }));
    }

    get chart() {
        const data = this.board.data;
        const trend = data?.trend ?? [];
        const n = trend.length;
        if (n < 2) {
            return null;
        }
        const plotW = VIEW.w - VIEW.padL - VIEW.padR;
        const plotH = VIEW.h - VIEW.padT - VIEW.padB;
        const x = (i) => VIEW.padL + (i * plotW) / (n - 1);
        const y = (v) => VIEW.padT + (1 - v / Y_MAX) * plotH;
        const r1 = (v) => Math.round(v * 10) / 10;

        const last = trend[n - 1];
        const baselineY = r1(y(data.baselineDays));
        return {
            points: trend.map((p, i) => `${r1(x(i))},${r1(y(p.days))}`).join(' '),
            baselineY,
            baselineLabelY: baselineY - 6,
            baselineLabel: data.baselineLabel,
            dotX: r1(x(n - 1)),
            dotY: r1(y(last.days)),
            endLabelX: r1(x(n - 1)) + 10,
            endLabelY: r1(y(last.days)) + 4,
            endText: `${last.days} days`,
            firstLabel: trend[0].label,
            lastLabel: last.label,
            lastX: r1(x(n - 1))
        };
    }

    get pipeline() {
        return this.board.data?.pipeline ?? null;
    }
    get clientCells() {
        return this.pipeline?.clientSide ?? [];
    }
    // Candidate side renders outward from the center chip, so its funnel is
    // reversed: chip ← outreach ← flagged ← screened ← applications. Read
    // right-to-left it is the funnel; both sides converge on placements.
    get candidateCellsInward() {
        return [...(this.pipeline?.candidateSide ?? [])].reverse();
    }
    get placements() {
        return this.pipeline?.placements;
    }
}
