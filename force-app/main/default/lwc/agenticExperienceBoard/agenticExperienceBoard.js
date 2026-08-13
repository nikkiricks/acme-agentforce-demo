import { LightningElement, api, wire } from 'lwc';
import getCandidateSideStats from '@salesforce/apex/AgenticExperienceBoardController.getCandidateSideStats';
import getBoardMetrics from '@salesforce/apex/AgenticExperienceBoardController.getBoardMetrics';

// SVG chart geometry. Fixed y-domain 0–10.5 days so the 9.5 pre-agent
// baseline and the ~3.2 series always fit and the axis never rescales when
// the granularity toggles — a rescaling axis would visually lie about the trend.
const VIEW = { w: 600, h: 220, padL: 14, padR: 104, padT: 20, padB: 28 };
const Y_MAX = 10.5;
const FLOOR_Y = VIEW.h - VIEW.padB; // 192
const VOLUME_MAX_H = 95; // volume area peaks at ~55% of plot height — background, not co-star

// Persona-scoped presentation. The data service returns a superset payload
// and does not know personas exist; everything audience-specific lives here.
const PERSONAS = {
    board: {
        title: 'Acme Agentic Experience — Board View',
        subtitle: 'Agentic hiring rollout · all customers, one platform',
        chip: 'Dana · Chief Executive Officer',
        chartTitle: 'Median time-to-shortlist across live customers',
        badgeTile: 'screenedPlatform',
        badgeText: (n) => `+${n} live in this workspace · LIVE FROM CRM`,
        showVolume: false,
        heroStage: null
    },
    product: {
        title: 'Acme Agentic Experience — Product View',
        subtitle: 'Agentic screening · adoption, quality, and build velocity',
        chip: 'Priya · VP of Product',
        chartTitle: 'Time-to-shortlist held while screening volume went 5x',
        badgeTile: 'activeRecruiters',
        badgeText: (n) => `+${n} screened in this workspace · LIVE FROM CRM`,
        showVolume: true,
        heroStage: 'Flagged for review'
    }
};

export default class AgenticExperienceBoard extends LightningElement {
    // Set per Lightning page in App Builder ('board' | 'product') — persona is
    // configuration, never an in-component toggle.
    @api persona = 'board';

    granularity = 'WEEKLY';

    @wire(getCandidateSideStats) candidateStats;
    // Reactive $granularity: toggling refetches; cacheable=true makes
    // toggling back instant from the client cache.
    @wire(getBoardMetrics, { granularity: '$granularity' }) board;

    get personaConfig() {
        return PERSONAS[this.persona] ?? PERSONAS.board;
    }
    get title() {
        return this.personaConfig.title;
    }
    get subtitle() {
        return this.personaConfig.subtitle;
    }
    get personaChip() {
        return this.personaConfig.chip;
    }
    get personaInitial() {
        return this.personaConfig.chip.charAt(0);
    }
    get chartTitle() {
        return this.personaConfig.chartTitle;
    }

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

    // Exactly 4 tiles in either persona — the persona swaps content, never
    // adds elements. The live workspace count rides as a badge on the tile
    // the persona designates.
    get displayTiles() {
        const data = this.board.data;
        if (!data) {
            return [];
        }
        const cfg = this.personaConfig;
        const tiles =
            this.persona === 'product'
                ? [data.activeRecruiters, data.overrideRate, data.firstResponse, data.releaseVelocity]
                : data.tiles;
        const liveCount = this.candidateStats.data?.screenedCount;
        return (tiles ?? []).filter(Boolean).map((t) => ({
            ...t,
            glyph: t.delta ? (t.delta.up ? '▲' : '▼') : undefined,
            deltaText: t.delta ? `${t.delta.amount} ${t.delta.label}` : undefined,
            liveBadge:
                t.key === cfg.badgeTile && liveCount !== undefined
                    ? cfg.badgeText(liveCount)
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

        // Product persona: neutral-gray screening-volume area behind the
        // line. Own implicit scale, direct-labeled endpoint — one axis, no
        // legend, the label does the naming.
        let volumePoints;
        let volumeLabel;
        const vols = data.volume ?? [];
        if (this.personaConfig.showVolume && vols.length === n) {
            const vMax = Math.max(...vols);
            const yV = (v) => FLOOR_Y - (v / vMax) * VOLUME_MAX_H;
            volumePoints =
                `${r1(x(0))},${FLOOR_Y} ` +
                vols.map((v, i) => `${r1(x(i))},${r1(yV(v))}`).join(' ') +
                ` ${r1(x(n - 1))},${FLOOR_Y}`;
            volumeLabel = {
                x: r1(x(n - 1)) + 10,
                y: r1(yV(vols[n - 1])) + 4,
                text: data.volumeEndLabel
            };
        }

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
            lastX: r1(x(n - 1)),
            volumePoints,
            volumeLabel
        };
    }

    get pipeline() {
        return this.board.data?.pipeline ?? null;
    }
    get clientCells() {
        return (this.pipeline?.clientSide ?? []).map((c) => ({
            ...c,
            cls: 'pipeline-cell'
        }));
    }
    // Candidate side renders outward from the center chip, so its funnel is
    // reversed: chip ← outreach ← flagged ← screened ← applications. Read
    // right-to-left it is the funnel; both sides converge on placements.
    // Product persona promotes the flagged stage to the accented hero node —
    // the human-in-the-loop checkpoint.
    get candidateCellsInward() {
        const hero = this.personaConfig.heroStage;
        return [...(this.pipeline?.candidateSide ?? [])].reverse().map((c) => {
            const isHero = hero !== null && c.label === hero;
            return {
                ...c,
                cls: isHero ? 'pipeline-cell pipeline-cell_hero' : 'pipeline-cell',
                heroCaption: isHero ? 'human-in-the-loop checkpoint' : undefined
            };
        });
    }
    get placements() {
        return this.pipeline?.placements;
    }
}
