{{/*
Expand the name of the chart.
*/}}
{{- define "claude-code-observability.name" -}}
{{- .Chart.Name }}
{{- end }}

{{/*
Common labels applied to all resources.
*/}}
{{- define "claude-code-observability.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Service name helpers — all services are prefixed with the release name so
multiple installs in the same namespace don't collide.
*/}}
{{- define "claude-code-observability.prometheusHost" -}}
{{- printf "%s-prometheus" .Release.Name }}
{{- end }}

{{- define "claude-code-observability.lokiHost" -}}
{{- printf "%s-loki" .Release.Name }}
{{- end }}

{{- define "claude-code-observability.otelCollectorHost" -}}
{{- printf "%s-otel-collector" .Release.Name }}
{{- end }}

{{- define "claude-code-observability.grafanaHost" -}}
{{- printf "%s-grafana" .Release.Name }}
{{- end }}

{{/*
PVC storageClassName: omit the field entirely when storageClass is empty so
the cluster's default StorageClass is used.
*/}}
{{- define "claude-code-observability.storageClassName" -}}
{{- if . }}
storageClassName: {{ . }}
{{- end }}
{{- end }}
