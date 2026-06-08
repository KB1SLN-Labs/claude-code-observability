# claude-code-observability

A self-hosted monitoring stack for [Claude Code](https://claude.ai/code). Claude Code already emits OpenTelemetry data — this stack gives you somewhere useful to send it.

**Stack:** OpenTelemetry Collector → Prometheus (metrics) + Loki (logs) → Grafana

## What you get

- Real-time cost burn rate with today-vs-yesterday trend indicators and 7-day rolling averages
- Subagent vs. main session cost split — see how much of your spend is autonomous parallel work
- Cost forecasting — daily and monthly projections from the current burn rate
- Cost anomaly detection — hourly deviation from your 7-day historical baseline
- Per-model token efficiency comparison (tokens per dollar)
- Cache hit rate tracking with threshold indicators
- Lines of code added and removed with daily and 7-day averages
- File edit acceptance vs. rejection rate
- Tool usage breakdown by type, sourced from structured logs
- Tool decision authorization sources — config vs. user-approved
- Prompt frequency and character length distribution
- Active CLI and user time
- Raw log stream with level filtering and session drill-down

## Deployment options

Three ways to run the stack — pick the one that matches your environment:

| Option | Best for |
|--------|----------|
| [Docker Compose](#docker-compose) | Quickest start. Single machine, local or remote. No cluster needed. |
| [Kubernetes (Kustomize)](#kubernetes) | Existing cluster, no Helm. Raw manifests, easy to inspect and modify. |
| [Helm](#helm) | Existing cluster with Helm. Easiest to customize and upgrade. |

All three options deploy the same four services and the same Grafana dashboards.

## Requirements

- Claude Code with OTEL export configured (see below)
- **Docker Compose:** Docker and Docker Compose
- **Kubernetes (Kustomize):** A Kubernetes cluster and `kubectl` (v1.14+, which includes Kustomize)
- **Helm:** A Kubernetes cluster and [Helm](https://helm.sh/) v3

---

## Docker Compose

### Setup

**1. Clone the repo:**

```bash
git clone https://github.com/KB1SLN-Labs/claude-code-observability.git
cd claude-code-observability
```

**2. (Optional) Adjust ports:**

If any default ports conflict with something already running on your host, copy `.env.example` to `.env` and change the values you need:

```bash
cp .env.example .env
```

```env
GRAFANA_PORT=3000
OTLP_GRPC_PORT=4317
OTLP_HTTP_PORT=4318
PROMETHEUS_PORT=9090   # commonly conflicts — change this if needed
LOKI_PORT=3100
```

Only set the values you're changing. The defaults apply for anything you leave out.

**3. Start the stack:**

```bash
docker compose up -d
```

**4. Configure Claude Code to export telemetry:**

How you configure the endpoint depends on where the stack is running.

**Same machine as Claude Code** — use `localhost` and the OTLP HTTP port (default 4318):

```json
{
  "env": {
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://localhost:4318",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf"
  }
}
```

**Stack running on a remote host** — replace `<stack-host>` with the IP address or hostname of the machine running Docker, and use whatever port you set for `OTLP_HTTP_PORT`:

```json
{
  "env": {
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://<stack-host>:4318",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf"
  }
}
```

Add this to your Claude Code `settings.json` (usually at `~/.claude/settings.json`) and restart Claude Code.

**5. Open Grafana:**

Navigate to `http://<stack-host>:3000` (or `http://localhost:3000` if running locally). Dashboards load automatically — no login required.

### Data retention

Prometheus retains 30 days of metrics by default. Loki retains logs until disk pressure triggers cleanup. Both can be adjusted in `docker-compose.yml`.

### Ports

All ports are configurable via `.env`. These are the defaults:

| Variable | Default | Service |
|----------|---------|---------|
| `GRAFANA_PORT` | 3000 | Grafana |
| `OTLP_GRPC_PORT` | 4317 | OTLP gRPC (collector) |
| `OTLP_HTTP_PORT` | 4318 | OTLP HTTP (collector) |
| `PROMETHEUS_PORT` | 9090 | Prometheus |
| `LOKI_PORT` | 3100 | Loki |

Only Grafana (for the UI) and the OTLP HTTP port (for Claude Code) need to be reachable from wherever you run Claude. Prometheus and Loki are internal to the stack and their ports only matter if you want to query them directly.

### Stopping

```bash
docker compose down
```

To remove all stored data:

```bash
docker compose down -v
```

---

## Kubernetes

Manifests are in the `k8s/` directory and use [Kustomize](https://kustomize.io/), which is built into `kubectl` since v1.14 — no separate install needed.

Grafana and the OTel Collector are exposed via `LoadBalancer` services by default. If your cluster doesn't have a load balancer provisioner (bare metal, local clusters, etc.), change `type: LoadBalancer` to `type: NodePort` in `k8s/otel-collector.yaml` and `k8s/grafana.yaml`. The assigned node ports will be shown by `kubectl get svc -n claude-code-observability`.

### Setup

**1. Clone the repo:**

```bash
git clone https://github.com/KB1SLN-Labs/claude-code-observability.git
cd claude-code-observability
```

**2. Deploy to your cluster:**

```bash
kubectl apply -k k8s/
```

This creates the `claude-code-observability` namespace and deploys all four services. PersistentVolumeClaims are created using your cluster's default StorageClass.

**3. Wait for external IPs to be assigned:**

```bash
kubectl get svc -n claude-code-observability --watch
```

Wait until both `otel-collector` and `grafana` show an `EXTERNAL-IP` (or a node port if you switched to NodePort).

**4. Configure Claude Code to export telemetry:**

Point Claude Code at the OTel Collector's external IP:

```json
{
  "env": {
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://<otel-collector-external-ip>:4318",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf"
  }
}
```

Add this to your Claude Code `settings.json` (usually at `~/.claude/settings.json`) and restart Claude Code.

**5. Open Grafana:**

Navigate to `http://<grafana-external-ip>:3000`. Dashboards load automatically — no login required.

### Data retention

Prometheus and Loki each get a 10Gi PersistentVolumeClaim by default. Prometheus is configured to retain 30 days of metrics. Adjust PVC sizes in `k8s/prometheus.yaml` and `k8s/loki.yaml` before first deploy.

### Tearing down

```bash
kubectl delete -k k8s/
```

This removes all workloads and services but leaves the PersistentVolumeClaims intact so data survives accidental teardowns. To remove everything including stored data:

```bash
kubectl delete -k k8s/
kubectl delete pvc -n claude-code-observability --all
```

---

## Helm

The Helm chart is in the `helm/` directory. It supports the same four-service stack as the Kubernetes manifests but is easier to customize — all tunables (image versions, service types, PVC sizes, retention, resource limits) are in `values.yaml`.

Grafana and the OTel Collector are exposed via `LoadBalancer` services by default. If your cluster doesn't have a load balancer provisioner, set `otelCollector.service.type` and `grafana.service.type` to `NodePort` in your values override.

### Setup

**1. Clone the repo:**

```bash
git clone https://github.com/KB1SLN-Labs/claude-code-observability.git
cd claude-code-observability
```

**2. Install the chart:**

```bash
helm install claude-code ./helm --namespace claude-code-observability --create-namespace
```

To override defaults — for example, to use a specific StorageClass or switch to NodePort:

```bash
helm install claude-code ./helm \
  --namespace claude-code-observability \
  --create-namespace \
  --set prometheus.persistence.storageClass=standard \
  --set otelCollector.service.type=NodePort \
  --set grafana.service.type=NodePort
```

**3. Wait for external IPs to be assigned:**

```bash
kubectl get svc -n claude-code-observability --watch
```

Wait until `claude-code-otel-collector` and `claude-code-grafana` show an `EXTERNAL-IP` (or node port if you switched to NodePort).

**4. Configure Claude Code to export telemetry:**

Point Claude Code at the OTel Collector's external IP:

```json
{
  "env": {
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://<otel-collector-external-ip>:4318",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf"
  }
}
```

Add this to your Claude Code `settings.json` (usually at `~/.claude/settings.json`) and restart Claude Code.

**5. Open Grafana:**

Navigate to `http://<grafana-external-ip>:3000`. Dashboards load automatically — no login required.

### Customization

All values are in `helm/values.yaml`. The most commonly changed ones:

| Value | Default | Description |
|-------|---------|-------------|
| `prometheus.retention` | `30d` | How long Prometheus keeps metrics |
| `prometheus.persistence.size` | `10Gi` | Prometheus PVC size |
| `loki.persistence.size` | `10Gi` | Loki PVC size |
| `otelCollector.service.type` | `LoadBalancer` | `LoadBalancer` or `NodePort` |
| `grafana.service.type` | `LoadBalancer` | `LoadBalancer` or `NodePort` |
| `otelCollector.service.annotations` | `{}` | Cloud load balancer annotations (e.g. AWS NLB) |
| `grafana.service.annotations` | `{}` | Cloud load balancer annotations |

### Upgrading

```bash
helm upgrade claude-code ./helm --namespace claude-code-observability
```

### Tearing down

```bash
helm uninstall claude-code --namespace claude-code-observability
```

This removes all workloads and services but leaves the PersistentVolumeClaims intact. To remove everything including stored data:

```bash
helm uninstall claude-code --namespace claude-code-observability
kubectl delete pvc -n claude-code-observability --all
```

---

## Dashboard reference

There are two dashboards: **Claude Code** (main) and **Claude Code — Logs**.

### Claude Code (main)

The default time range is the last 24 hours. The dashboard refreshes every 5 minutes. Most stat panels show a current value alongside a 7-day rolling average. Panels with sparklines also show a percentage change indicator comparing the current 24-hour window to the same window yesterday.

---

#### Cost Summary

Five stat panels across the top row.

**Real-Time Cost Burn Rate**
Current spend rate in dollars per hour, calculated from a 30-minute trailing window. The window is intentionally wide — Claude Code emits metrics per API turn rather than continuously, so a shorter window zeros out between turns. Background turns green below $0.50/hr, yellow up to $2.00/hr, red above.

**Total Cost Today**
Total API spend in the last 24 hours alongside the 7-day rolling daily average. The percentage change compares today's 24-hour window to yesterday's. If today is well above your 7-day average and trending up, check whether a session is accumulating more context than usual.

**Subagent Cost (24h)**
Cost attributed to spawned subagent tasks — parallel research, background code review, multi-agent work. Compare against Main Session Cost to understand what fraction of your spend is autonomous parallel work versus direct conversation. Includes the 7-day average and today-vs-yesterday change.

**Main Session Cost (24h)**
Cost from primary conversation turns: your prompts and Claude's direct responses. Excludes subagent and auxiliary tasks. Includes the 7-day average and percentage change.

**Code Edit Acceptance Rate %**
Percentage of Claude's proposed file edits that were accepted in the last 24 hours, plus the 7-day average. Below 80% is worth investigating — the most common causes are context drift mid-session, an ambiguous task description, or Claude losing track of the codebase structure. Background turns red below 60%, yellow up to 80%, green above. Shows "No edits" if no edit activity occurred in the window.

---

#### Projections and Per-Session Metrics

**Cost Forecast**
Daily and monthly cost projections extrapolated from the current 6-hour burn rate. Useful for catching a runaway session before the bill arrives. Because it uses a 6-hour window, the number smooths out short spikes and reflects sustained activity.

**Average Cost / Session**
Average API spend per session over the last 24 hours compared to the 7-day average. A rising number over multiple days usually means sessions are running longer without being compacted — context accumulates and each turn costs more to process.

**Cost per 1K Tokens**
Effective cost per 1,000 tokens across all token types. Cache reads cost roughly 10% of input price, so a well-cached workflow will push this number well below the model's headline rate. Includes the 7-day average and percentage change. Rising cost-per-token despite stable usage typically means cache efficiency has dropped.

**Active Time (24h)**
Two values side by side: CLI time (how long Claude Code was running and processing) and User time (how long you were actively engaged — typing, reviewing). A high CLI-to-user ratio means Claude is doing a lot of autonomous work between your interactions.

**Token Distribution by Model (24h)**
Pie chart showing the share of total tokens consumed by each model. Sonnet dominating is expected for most workloads. A large Opus slice is worth checking — Opus costs roughly 5x Sonnet per token, and many tasks don't require it.

---

#### Session Volume

**Active Sessions (24h)**
Number of Claude Code sessions started in the last 24 hours, alongside the 7-day daily average and today-vs-yesterday change.

**Average Session Metrics**
Three horizontal bars showing per-session averages across the last 24 hours: cost ($), total token count, and active CLI time. Rising values across multiple days point to sessions accumulating context without being reset. A useful complement to Average Cost / Session — if cost is rising but token count is flat, a more expensive model is being used more often.

**Lines of Code Modified**
Lines added and deleted today alongside 7-day rolling daily averages for each. A large gap between Today and 7 Day Avg indicates an unusually active or unusually quiet day.

---

#### Cache and Token Health

**Cache Hit Rate %**
Percentage of input-side tokens served from Anthropic's prompt cache. Above 80% is healthy. Below 60% is a signal to investigate — sessions may be too short to warm the cache effectively, or context structure is preventing cache blocks from being reused. Gauge arc turns red below 60%, yellow up to 80%, green above.

**Total Tokens Today**
All tokens consumed in the last 24 hours across all types, alongside the 7-day daily average.

**Model Token Efficiency (tokens/$)**
Total tokens per dollar spent, broken down by model, over the selected time range. Higher is more efficient. Haiku should significantly outperform Opus given the price difference. If the gap is narrower than expected, check whether model selection is being overridden somewhere.

**Tool Usage Breakdown**
Donut chart of tool calls by type over the selected time range, sourced from structured logs. Covers all tools: Bash, Read, Edit, Write, Glob, Grep, and others. Heavy Bash usage looks like a lot of shell-and-test work; heavy Edit/Write usage is more code generation. Useful for understanding what kind of work Claude is actually doing.

---

#### Trends and History

**Peak Cost Hours**
API spend per hour displayed as a bar chart. Spikes show which hours were most expensive. Useful for correlating high-cost periods with specific tasks or sessions you remember running.

**Weekly Total Token Usage**
Total tokens consumed over the last 7 days with a sparkline showing the daily trend. A consistently rising slope means usage is accelerating week over week.

**Cost Anomaly Detection**
Hourly spend expressed as percentage deviation from the 7-day historical average for the same hour. A value of 0% means today's spend exactly matches the historical average; 200% means it's three times higher. Excursions above 200% are flagged in red as anomalies — investigate what was running during those periods.

**Prompts Per Hour**
Count of user prompt events over a rolling 1-hour window, sourced from structured logs. Peaks show concentrated interaction periods; flat sections are idle time. If this number looks too low, check that structured log export is reaching Loki.

**Tool Decision Sources (24h)**
Donut chart showing how tool executions were authorized: via CLAUDE.md or settings (`config`), approved once for the session (`user temporary`), or added to the permanent allow list (`user permanent`). A high `user temporary` fraction means you're approving many tools interactively that could be moved to config.

---

#### Rates and Distributions

**Code Modification Velocity (lines/min)**
Lines added and removed per minute as a timeseries. Green is additions, red is removals. Spikes indicate concentrated editing bursts. A sustained high removal rate relative to additions typically means refactoring or large-scale cleanup.

**Token Usage Rate (24h)**
Total tokens consumed per minute. The legend table shows mean, last, and peak rates for the selected window. Use this to gauge proximity to your plan's TPM rate limit. If the rate approaches your ceiling, starting a fresh session or running `/compact` is the appropriate response.

**Prompt Length Distribution (chars)**
Character count distribution across five buckets: under 100, 100–499, 500–999, 1k–4.9k, and 5k+, sourced from structured logs. Most prompts are short. Long prompts (1k+) usually indicate pasted code, error output, or a detailed task description. A spike in the 5k+ bucket during a session that went expensive is often the explanation.

---

### Claude Code — Logs

A dedicated log explorer linked from the main dashboard. Filter by severity level and optionally paste a session ID to scope to a single session.

**Errors / Warnings / Total Entries / Active Sessions**
Stat tiles showing counts for the selected time range. Use these to quickly gauge whether a period had unusual error rates before opening the full log stream.

**Log Volume Over Time**
Error, warning, and total log entry counts per minute as a timeseries. Error and warning spikes here are the signal to scroll down and investigate.

**Log Stream**
Full filterable log stream. Set the Level variable to narrow by severity. Paste a session ID in the Session ID field to isolate a single session. Click any row to expand the full structured payload.
