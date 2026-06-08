# claude-code-observability

A self-hosted monitoring stack for [Claude Code](https://claude.ai/code). Claude Code already emits OpenTelemetry data — this stack gives you somewhere useful to send it.

**Stack:** OpenTelemetry Collector → Prometheus (metrics) + Loki (logs) → Grafana

## What you get

- Real-time cost burn rate with 24-hour totals and 7-day rolling average
- Token usage broken down by type (input, output, cacheRead, cacheCreation)
- Cache efficiency tracking — hit rate over time and reuse ratio
- Per-model cost and token efficiency comparison
- Context snowball detection — catch runaway context before it hits the TPM ceiling
- Lines of code added/removed with daily and weekly averages
- Commit tracking over time
- File edit acceptance vs. rejection rate
- Active CLI and user time
- Raw log stream with level filtering and session drill-down

## Requirements

- Docker and Docker Compose
- Claude Code with OTEL export configured (see below)

## Setup

**1. Clone and start the stack:**

```bash
git clone https://github.com/KB1SLN-Labs/claude-code-observability.git
cd claude-code-observability
docker compose up -d
```

**2. Configure Claude Code to export telemetry:**

Add the following to your Claude Code `settings.json` (usually at `~/.claude/settings.json`):

```json
{
  "env": {
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://localhost:4318",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf"
  }
}
```

Restart Claude Code after saving.

**3. Open Grafana:**

Navigate to [http://localhost:3000](http://localhost:3000). Dashboards load automatically — no login required.

## Data retention

Prometheus retains 30 days of metrics by default. Loki retains logs until disk pressure triggers cleanup. Both can be adjusted in `docker-compose.yml`.

## Ports

| Port | Service |
|------|---------|
| 3000 | Grafana |
| 4317 | OTLP gRPC (collector) |
| 4318 | OTLP HTTP (collector) |
| 9090 | Prometheus |
| 3100 | Loki |

## Stopping

```bash
docker compose down
```

To remove all stored data:

```bash
docker compose down -v
```

---

## Dashboard reference

There are two dashboards: **Claude Code** (main) and **Claude Code — Logs**.

### Claude Code (main)

The default time range is the last 24 hours. The dashboard refreshes every 5 minutes.

---

#### Key Numbers

Eight stat tiles across the top. All values are scoped to the last 24 hours unless noted.

**Cost Burn Rate ($/hr)**
Average spend rate in dollars per hour, calculated over the last 30 minutes and annualized. If you spent $1.50 in the last 30 minutes, this shows $3.00/hr. The window is intentionally wide — Claude Code emits metrics per API turn, not continuously, so a shorter window zeros out between turns. Background turns green below $0.50/hr, yellow up to $2.00/hr, red above that.

**Cost Today**
Total API spend in the last 24 hours across all sessions and models.

**7-Day Avg Cost**
Rolling average of daily cost over the past 7 days. Compare it against Cost Today — if today is significantly above the 7-day average, you're having an expensive session.

**Cost per Session**
Cost Today divided by Sessions Today. A rising number over days usually means context is snowballing — sessions are running longer and accumulating more tokens before being reset.

**Cache Hit Rate**
Percentage of input-side tokens served from Anthropic's prompt cache. Above 80% is healthy — cache is doing its job. Below 60% is a signal to investigate: either context is growing too fast, or cache blocks are being invalidated frequently. Background turns red below 60%, yellow up to 80%, green above.

**Tokens Today**
All tokens consumed in the last 24 hours across all four types.

**Tokens per Session**
Tokens Today divided by Sessions Today. Useful for spotting sessions that are consuming disproportionately more tokens than usual.

**Sessions Today**
Number of Claude Code sessions in the last 24 hours.

---

#### Token Activity

**Token Burn Rate — All Types Over Time**
Token consumption rate broken down by type: input, output, cacheRead, cacheCreation. In a healthy long session, cacheRead should dominate. A spike in input without a matching cacheRead rise means the context is growing without hitting cache.

**Input vs Cache Read — Context Snowball Detector**
Focused view of just input and cacheRead tokens. When input climbs toward or above cacheRead, context is snowballing — the model is processing more new tokens than cached ones each turn. This is the signal to run `/compact` before you hit the TPM ceiling.

**Cost Burn Rate by Model — $/min**
Real-time cost per minute broken down by model. Opus appearing here at scale is the most common cause of unexpected bills. If a task doesn't require Opus-level reasoning, check whether Sonnet or Haiku could handle it.

---

#### Token Breakdown

**Token Volume by Type**
Cumulative token counts split by type. cacheRead dwarfing input is the signature of an efficient, well-cached workflow.

**Total Cost by Session — Top 10**
Most expensive sessions in the selected time range. A single session dominating this table usually means a very long context window or heavy Opus usage.

**Cost per 1k Output Tokens**
Effective cost per 1,000 output tokens across all sessions. Benchmark: Sonnet is around $0.015 per 1k output tokens, Opus is around $0.075. Higher than expected means Opus is being used heavily or poor cache reuse is driving up context costs.

**Cache Reuse Ratio**
cacheRead tokens divided by cacheCreation tokens — how many times each cached block is being reused on average. Above 5 means the cache is paying for itself. Below 2 means you're writing cache entries that rarely get reused.

**Session Count Over Time**
Active sessions per interval. Each line is a distinct session ID. Overlapping lines mean concurrent Claude Code sessions are running.

---

#### Development Output

**Lines of Code Modified**
Horizontal bar gauge showing lines added and removed. Each metric has a Today value (last 24h) and a 7 Day Avg (rolling daily average over the past week). Comparing Today vs. 7 Day Avg shows whether the current day is above or below your normal output.

**Model Token Efficiency (tokens/$)**
Total tokens per dollar spent, broken down by model. Higher is more efficient — you get more tokens for your money. Haiku should significantly outperform Opus here given the price difference. If the gap is smaller than expected, check whether model selection is being overridden somewhere.

**Weekly Token Usage**
Total tokens consumed in the last 7 days. The sparkline shows the daily trend — a rising slope means usage is accelerating.

**Total Commits**
Commits made during Claude Code sessions in the selected time range.

**Lines of Code (timeseries)**
Lines added and removed over time. Added is green, removed is red. Useful for seeing when in a session code was written versus deleted.

**Commits over Time**
Commit frequency as a timeseries. Spikes indicate concentrated commit activity during a session.

---

#### Rate Limit Proximity & Cache Health

**Cache Hit Rate Over Time**
Cache hit rate trend over the selected time window with threshold bands drawn at 60% (yellow) and 80% (green). Sustained drops below 80% are a signal to restructure long sessions. A sudden mid-session drop usually means a large new block of text invalidated the cache.

**Token Burn Rate — Tokens/min**
Tokens consumed per minute across all types, stacked. Use this to gauge proximity to your TPM rate limit. A sustained high rate approaching your plan's ceiling is the trigger to start a fresh session.

---

#### Tool & Edit Intelligence

**Edit Acceptance Rate**
Percentage of Claude's file edits that were accepted versus rejected in the selected time range. Below 80% suggests Claude is producing edits that need rework — often a sign of context drift or an ambiguous task description. Background turns red below 60%, yellow up to 80%, green above.

**Active CLI Time**
Total time Claude Code was running and processing in the selected time range.

**Active User Time**
Total time you spent actively engaged — typing, reviewing — while Claude Code was running.

**Total File Edits**
Total file edit operations (Edit, Write, NotebookEdit) attempted by Claude in the selected time range.

**Edit Tool Usage**
Horizontal bar gauge showing edit operation counts by tool type. Edit modifies existing files in-place. Write creates or fully overwrites files. NotebookEdit targets Jupyter notebook cells.

**Edit Decisions — Accept vs Reject**
Accept count in green, reject count in red. A high reject count relative to accepts points to edit quality or scope issues.

**Edit Decisions Over Time**
Accept and reject counts per 5-minute window. A rising reject rate mid-session often signals context drift — Claude losing track of the codebase state as context grows.

---

### Claude Code — Logs

A dedicated log explorer linked from the main dashboard. Filter by severity level and optionally paste a session ID to scope to a single session.

**Errors / Warnings / Total Entries / Active Sessions**
Stat tiles showing counts for the selected time range. Use these to quickly gauge whether a period of activity had unusual error rates before opening the log stream.

**Log Volume Over Time**
Error, warning, and total log entry counts per minute as a timeseries. Error and warning spikes here are the signal to scroll down and investigate the log stream.

**Log Stream**
Full filterable log stream. Set the Level variable to narrow by severity. Paste a session ID in the Session ID field to isolate a single session. Click any row to expand the full structured payload.
