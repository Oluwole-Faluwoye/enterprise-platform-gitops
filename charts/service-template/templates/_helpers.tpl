{{/*
Expand the name of the chart.
*/}}
{{- define "service-template.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a fully qualified app name.

If fullnameOverride is provided, use it.
Otherwise use service.name when supplied.
*/}}
{{- define "service-template.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .Values.service.name }}
{{- .Values.service.name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- include "service-template.name" . | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version.
*/}}
{{- define "service-template.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "service-template.labels" -}}
helm.sh/chart: {{ include "service-template.chart" . }}
{{ include "service-template.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Values.global.project }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
environment: {{ .Values.global.environment }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "service-template.selectorLabels" -}}
app.kubernetes.io/name: {{ include "service-template.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "service-template.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "service-template.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the Kubernetes Secret name for the service.
*/}}
{{- define "service-template.secretName" -}}
{{- printf "%s-secret" (include "service-template.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create the AWS Secrets Manager path for the service.
*/}}
{{- define "service-template.awsSecretPath" -}}
{{- printf "%s/%s/%s" .Values.global.project .Values.global.environment (include "service-template.fullname" .) }}
{{- end }}