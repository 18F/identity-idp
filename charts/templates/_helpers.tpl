{{/*
Expand the name of the chart.
*/}}
{{- define "identity-idp-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "identity-idp-chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "identity-idp-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "identity-idp-chart.idp.labels" -}}
helm.sh/chart: {{ include "identity-idp-chart.chart" . }}
{{ include "identity-idp-chart.idp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "identity-idp-chart.idp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "identity-idp-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "identity-idp-chart.idp.serviceAccountName" -}}
{{- if .Values.worker.serviceAccount.create }}
{{- default (printf "%s-idp" (include "identity-idp-chart.fullname" .)) .Values.worker.serviceAccount.name }}
{{- else }}
{{- default (printf "%s-idp" "default") .Values.worker.serviceAccount.name }}
{{- end }}
{{- end }}

# templates/_helpers.tpl
{{/*
idp fullname
*/}}
{{- define "identity-idp-chart.idp.fullname" -}}
{{- printf "%s-idp" (include "identity-idp-chart.fullname" .) -}}
{{- end -}}

# templates/_helpers.tpl
{{/*
Redis fullname
*/}}
{{- define "identity-idp-chart.redis.fullname" -}}
{{- printf "%s-redis" (include "identity-idp-chart.fullname" .) -}}
{{- end -}}

{{/*
Redis labels
*/}}
{{- define "identity-idp-chart.redis.labels" -}}
helm.sh/chart: {{ include "identity-idp-chart.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/name: redis
{{- end -}}

{{/*
Redis selector labels
*/}}
{{- define "identity-idp-chart.redis.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: redis
{{- end -}}

{{/*
Postgres fullname
*/}}
{{- define "identity-idp-chart.postgres.fullname" -}}
{{- printf "%s-postgres" (include "identity-idp-chart.fullname" .) -}}
{{- end -}}

{{/*
Postgres labels
*/}}
{{- define "identity-idp-chart.postgres.labels" -}}
helm.sh/chart: {{ include "identity-idp-chart.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/name: postgres
{{- end -}}

{{/*
Postgres selector labels
*/}}
{{- define "identity-idp-chart.postgres.selectorLabels" -}}
app: {{ include "identity-idp-chart.postgres.fullname" . }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "identity-idp-chart.worker.labels" -}}
helm.sh/chart: {{ include "identity-idp-chart.chart" . }}
{{ include "identity-idp-chart.worker.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "identity-idp-chart.worker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "identity-idp-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "identity-idp-chart.worker.serviceAccountName" -}}
{{- if .Values.worker.serviceAccount.create }}
{{- default (printf "%s-worker" (include "identity-idp-chart.fullname" .)) .Values.worker.serviceAccount.name }}
{{- else }}
{{- default (printf "%s-worker" "default") .Values.worker.serviceAccount.name }}
{{- end }}
{{- end }}

# templates/_helpers.tpl
{{/*
worker fullname
*/}}
{{- define "identity-idp-chart.worker.fullname" -}}
{{- printf "%s-worker" (include "identity-idp-chart.fullname" .) -}}
{{- end -}}