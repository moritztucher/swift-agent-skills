---
description: Review an active Apple Search Ads campaign's performance and suggest improvements for the next 7 days
---

# ASO Review

Analyze an active Apple Search Ads campaign's performance by pulling data from your tracking source (e.g. a Notion database, spreadsheet, or the ASA API), comparing against other campaigns and historical periods, then providing actionable recommendations for the next 7 days.

## Setup

This skill assumes you track campaign metrics in a structured store. The reference implementation below uses a Notion workspace with four databases — adapt the data source step to wherever your metrics live (Notion, Airtable, Google Sheets, or the ASA reporting API directly).

| Database | Purpose |
|----------|---------|
| Campaigns | One row per active campaign (Name, Start Date, End Date, Status, Daily Budget) |
| Ad Groups | Ad-group-level configuration linked to a campaign |
| Metrics Logs | Per-keyword daily metrics (Impressions, Taps, Spend, Installs) |
| Strategy Decisions | Weekly Changes Logs recording bid adjustments and rationale |

Configure your own database IDs / sheet IDs in a local `.env` or settings file — do not commit them.

## Step-by-Step Instructions

### 1. Load Active Campaigns

1. Query the Campaigns store for campaigns where Status = "Active"
2. For each result, get its properties (Name, Start Date, End Date, Status, Daily Budget)
3. If no active campaigns are found, tell the user and stop

### 2. Present Campaign Selection

Display the active campaigns in a numbered list:

```
Which campaign would you like to review?

1. {Campaign Name A} ({Start} → {End}) — €X daily budget
2. {Campaign Name B} ({Start} → {End}) — €X daily budget
...
```

Use `AskUserQuestion` to let the user pick a campaign by number or name. Wait for their response before continuing.

### 3. Gather Campaign Data

Once the user selects a campaign:

1. **Fetch the campaign record** to get full properties and linked relations
2. **Fetch linked Ad Groups** via the campaign's "Ad Group" relation
3. **Fetch linked Metrics Logs** via the campaign's "Metrics Logs" relation
4. **Collect all keyword metrics:** For each metrics log entry, extract:
   - Keyword, Impressions, Taps, Spend, Installs, Date
   - The linked Ad Group name
5. **Group metrics by date** to understand daily/weekly trends

### 4. Check Previous Strategy Decisions

Before making recommendations, always check what was decided last time:

1. Search the Strategy Decisions store for Changes Logs related to the selected campaign
2. Fetch the most recent Changes Log to understand:
   - What bid changes, pauses, or new keywords were made last week
   - What follow-up questions or watch items were set
   - What actions were deferred to this week
3. **Evaluate outcomes:** Compare this week's metrics against last week's decisions — did the changes have the desired effect?
4. **Answer deferred questions:** If last week's log listed specific follow-up questions, answer them explicitly in the review
5. **Build on prior decisions:** Recommendations should be a continuation of the strategy, not a fresh start

### 5. Gather Comparison Data

To provide meaningful recommendations, also gather:

1. **Other active campaigns:** Metrics from other active campaigns in the same date range to compare CPA, TTR, and CR across geos/strategies
2. **Previous periods for the same campaign:** Metrics logs from earlier date ranges of the same campaign for period-over-period comparison
3. **Ad group performance across campaigns:** Compare how the same keywords perform in different geos/campaigns

### 6. Analyze Performance

Calculate and analyze the following metrics for the selected campaign:

#### Per-Keyword Analysis
| Metric | Formula |
|--------|---------|
| TTR (Tap-Through Rate) | Taps ÷ Impressions |
| CR (Conversion Rate) | Installs ÷ Taps |
| CPA (Cost Per Acquisition) | Spend ÷ Installs |
| CPT (Cost Per Tap) | Spend ÷ Taps |

#### Campaign-Level Analysis
- **Total spend** vs daily budget pace
- **Top performers:** Keywords with best CPA and CR
- **Underperformers:** Keywords with high spend but low/zero installs
- **Zero-data keywords:** Keywords with no impressions
- **Impression volume:** Keywords getting impressions but no taps

#### Cross-Campaign Comparison
- Compare CPA across geos
- Identify which geos are most efficient for each keyword
- Flag keywords that perform well in one campaign but poorly in another

#### Period-over-Period Comparison
- Compare current metrics to previous campaign periods
- Identify improving or declining keywords

### 7. Generate Recommendations

Based on the analysis, provide specific, actionable recommendations for the next 7 days:

```markdown
## Campaign Review: [Campaign Name]
**Period:** [Start Date] → [End Date]

### Performance Summary
| Metric | Value |
|--------|-------|
| Total Spend | €X |
| Total Installs | X |
| Avg CPA | €X |
| Avg CPT | €X |
| Overall TTR | X% |
| Overall CR | X% |

### Top Performing Keywords
[Table of top 5 keywords by install volume with all metrics]

### Underperforming Keywords
[Table of keywords with high spend but poor conversion]

### Cross-Campaign Comparison
[How this campaign compares to others in the same period]

### Period-over-Period Trends
[How performance has changed vs previous periods]

### Recommendations for Next 7 Days

#### Increase Bids
[Keywords with good CR but low impression share]

#### Decrease Bids / Pause
[Keywords bleeding budget with no returns]

#### Suggested Actions
[New keywords to test, ad group restructuring, budget reallocation]

#### Watch List
[Keywords showing early signs of decline or improvement]
```

### 8. Ask User What Changes Were Made

After presenting recommendations, **do NOT create the Changes Log automatically**. Instead, ask the user what changes they actually made in Apple Search Ads. Wait for their response.

### 9. Create Changes Log

Only after the user confirms what they did, create a Changes Log entry in the Strategy Decisions store reflecting the **actual changes made** (not the recommendations).

```markdown
## Changes Made — [Month] [Day], [Year]
**Campaign:** [Full Campaign Name]
**Reviewed Period:** [Start Date] → [End Date]
**Campaign Avg CPA:** €X | **Avg CPT:** €X | **Total Spend:** €X | **Installs:** X

---

### Bid Increases
| Keyword | Ad Group | Match | Previous Bid | New Bid | Rationale |
|---------|----------|-------|-------------|---------|-----------|

### Bid Decreases
| Keyword | Ad Group | Match | Previous Bid | New Bid | Rationale |
|---------|----------|-------|-------------|---------|-----------|

### Keywords Paused
| Keyword | Ad Group | Match | Reason |
|---------|----------|-------|--------|

---

### Next Review
- Check back after [current date + 7 days] to evaluate changes
- [Specific follow-up items from Watch List and recommendations]
```

### 10. Offer Follow-Up

After presenting the review and changelog link, offer to:
- Deep-dive into a specific ad group or keyword
- Compare with a specific other campaign
- Run recommendations on a different campaign

## Important Notes

- Always handle division by zero gracefully
- When comparing campaigns, normalize by time period length if dates differ
- Sort recommendations by estimated impact (highest potential improvement first)
- Be specific with bid change suggestions — reference actual CPT values and competitor ranges when available
- If data is sparse (campaign just started), note this and adjust recommendations accordingly
