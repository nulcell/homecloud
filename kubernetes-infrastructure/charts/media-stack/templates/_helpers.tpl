{{/*
Resolve the install namespace (defaults to .Release.Namespace).
*/}}
{{- define "mediaStack.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{/*
Chart name.
*/}}
{{- define "mediaStack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified release name.
*/}}
{{- define "mediaStack.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Chart label (helm.sh/chart).
*/}}
{{- define "mediaStack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels for any resource owned by the release.
Usage: {{ include "mediaStack.labels" (dict "ctx" . "app" "jellyfin") | nindent 4 }}
The `app` field becomes the app.kubernetes.io/component label (omit for global).
*/}}
{{- define "mediaStack.labels" -}}
helm.sh/chart: {{ include "mediaStack.chart" .ctx }}
app.kubernetes.io/name: {{ include "mediaStack.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
{{- if .ctx.Chart.AppVersion }}
app.kubernetes.io/version: {{ .ctx.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
{{- if .app }}
app.kubernetes.io/component: {{ .app }}
{{- end }}
{{- end -}}

{{/*
Selector labels for pod/svc matching. Stable across upgrades.
Usage: {{ include "mediaStack.selectorLabels" (dict "ctx" . "app" "jellyfin") | nindent 6 }}
*/}}
{{- define "mediaStack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mediaStack.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
{{- if .app }}
app.kubernetes.io/component: {{ .app }}
{{- end }}
{{- end -}}

{{/*
Standard PUID/PGID/TZ env vars for the linuxserver.io family of images.
Usage: {{ include "mediaStack.commonEnv" . | nindent 12 }}
*/}}
{{- define "mediaStack.commonEnv" -}}
- name: PUID
  value: {{ .Values.common.puid | quote }}
- name: PGID
  value: {{ .Values.common.pgid | quote }}
- name: TZ
  value: {{ .Values.common.timezone | quote }}
{{- end -}}

{{/*
Container-level securityContext. The linuxserver.io images start as root,
drop to PUID/PGID via s6-init, and need a small set of capabilities for that
hand-off. Defaults are pinned in values.common.securityContext.
*/}}
{{- define "mediaStack.containerSecurityContext" -}}
allowPrivilegeEscalation: {{ .Values.common.securityContext.allowPrivilegeEscalation }}
readOnlyRootFilesystem: {{ .Values.common.securityContext.readOnlyRootFilesystem }}
capabilities:
  drop:
    - ALL
  add:
{{ toYaml .Values.common.securityContext.capabilitiesAdd | indent 4 }}
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{/*
Pod-level securityContext. fsGroup matches PGID so the linuxserver.io
init step can chown volume mounts.
*/}}
{{- define "mediaStack.podSecurityContext" -}}
fsGroup: {{ .Values.common.pgid }}
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{/*
The shared config + data volumes block, referenced by every pod.
*/}}
{{- define "mediaStack.volumes" -}}
- name: config
  persistentVolumeClaim:
    claimName: {{ include "mediaStack.fullname" . }}-config
- name: data
  persistentVolumeClaim:
    claimName: {{ include "mediaStack.fullname" . }}-data
{{- end -}}

