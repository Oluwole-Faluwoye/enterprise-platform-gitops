{{/*
Expand the chart name.
*/}}
{{- define "monitoring-assets.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end }}

{{/*
Create a fully qualified name.
*/}}
{{- define "monitoring-assets.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride }}
{{- else }}
{{- include "monitoring-assets.name" . }}
{{- end }}
{{- end }}

{{/*
Namespace
*/}}
{{- define "monitoring-assets.namespace" -}}
{{- default "monitoring" .Values.namespace }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "monitoring-assets.labels" -}}
app.kubernetes.io/name: {{ include "monitoring-assets.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Standard annotations
*/}}
{{- define "monitoring-assets.annotations" -}}
{{- end }}