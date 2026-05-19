{{/*
Allow the release namespace to be overridden — kept consistent with n8n /
media-stack so the kustomize wrapper in gitops/security/falco/ feels familiar.
*/}}
{{- define "falcoStack.namespace" -}}
  {{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{- define "falcoStack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "falcoStack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Labels every resource gets. The Falco Operator stamps its own labels on the
Pods / Services it creates from the CRs — these are *our* chart labels and
exist alongside the operator's.
*/}}
{{- define "falcoStack.labels" -}}
helm.sh/chart: {{ include "falcoStack.chart" . }}
app.kubernetes.io/name: {{ include "falcoStack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: falco
{{- end }}
