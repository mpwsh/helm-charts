{{/*
Expand the name of the chart.
*/}}
{{- define "flint-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "flint-controller.fullname" -}}
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
{{- define "flint-controller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "flint-controller.labels" -}}
helm.sh/chart: {{ include "flint-controller.chart" . }}
{{ include "flint-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flint-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flint-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "flint-controller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "flint-controller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Namespace of the cluster state Secret.
*/}}
{{- define "flint-controller.stateNamespace" -}}
{{- default .Release.Namespace .Values.stateNamespace }}
{{- end }}

{{/*
Name of the Secret holding the provider API key.
*/}}
{{- define "flint-controller.providerSecretName" -}}
{{- if .Values.provider.existingSecret }}
{{- .Values.provider.existingSecret }}
{{- else }}
{{- printf "%s-provider" (include "flint-controller.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Environment variable the provider key is read from.
*/}}
{{- define "flint-controller.providerKeyEnv" -}}
{{- if eq .Values.provider.name "vultr" }}VULTR_API_KEY{{- else }}{{ fail (printf "unsupported provider %q (available: vultr)" .Values.provider.name) }}{{- end }}
{{- end }}
