{{/*
Expand the name of the chart.
*/}}
{{- define "clickvisual-stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "clickvisual-stack.fullname" -}}
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
{{- define "clickvisual-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "clickvisual-stack.labels" -}}
helm.sh/chart: {{ include "clickvisual-stack.chart" . }}
{{ include "clickvisual-stack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "clickvisual-stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "clickvisual-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
===========================================
MySQL Connection Helpers
===========================================
*/}}
{{- define "clickvisual-stack.mysql.host" -}}
{{- if .Values.mysql.enabled -}}
{{- printf "%s-mysql" .Release.Name }}
{{- else -}}
{{- .Values.mysql.external.host }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.mysql.port" -}}
{{- if .Values.mysql.enabled -}}
{{- .Values.mysql.primary.service.port | default 3306 }}
{{- else -}}
{{- .Values.mysql.external.port | default 3306 }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.mysql.database" -}}
{{- if .Values.mysql.enabled -}}
{{- .Values.mysql.auth.database | default "clickvisual" }}
{{- else -}}
{{- .Values.mysql.external.database | default "clickvisual" }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.mysql.username" -}}
{{- if .Values.mysql.enabled -}}
{{- .Values.mysql.auth.username | default "root" }}
{{- else -}}
{{- .Values.mysql.external.username | default "root" }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.mysql.password" -}}
{{- if .Values.mysql.enabled -}}
{{- .Values.mysql.auth.rootPassword | default "shimo" }}
{{- else -}}
{{- .Values.mysql.external.password }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.mysql.dsn" -}}
{{- $host := include "clickvisual-stack.mysql.host" . -}}
{{- $port := include "clickvisual-stack.mysql.port" . -}}
{{- $db := include "clickvisual-stack.mysql.database" . -}}
{{- $user := include "clickvisual-stack.mysql.username" . -}}
{{- $pass := include "clickvisual-stack.mysql.password" . -}}
{{- printf "%s:%s@tcp(%s:%v)/%s?charset=utf8mb4&collation=utf8mb4_general_ci&parseTime=True&loc=Local&readTimeout=1s&timeout=1s&writeTimeout=3s" $user $pass $host $port $db }}
{{- end -}}

{{/*
===========================================
Redis Connection Helpers
===========================================
*/}}
{{- define "clickvisual-stack.redis.host" -}}
{{- if .Values.redis.enabled -}}
{{- printf "%s-redis-master" .Release.Name }}
{{- else -}}
{{- .Values.redis.external.host }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.redis.port" -}}
{{- if .Values.redis.enabled -}}
{{- .Values.redis.master.service.port | default 6379 }}
{{- else -}}
{{- .Values.redis.external.port | default 6379 }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.redis.password" -}}
{{- if .Values.redis.enabled -}}
{{- .Values.redis.auth.password | default "" }}
{{- else -}}
{{- .Values.redis.external.password | default "" }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.redis.addr" -}}
{{- $host := include "clickvisual-stack.redis.host" . -}}
{{- $port := include "clickvisual-stack.redis.port" . -}}
{{- printf "%s:%v" $host $port }}
{{- end -}}

{{/*
===========================================
ClickHouse Connection Helpers
===========================================
*/}}
{{- define "clickvisual-stack.clickhouse.host" -}}
{{- if .Values.clickhouse.enabled -}}
{{- printf "%s-clickhouse" .Release.Name }}
{{- else -}}
{{- .Values.clickhouse.external.host }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.clickhouse.port" -}}
{{- if .Values.clickhouse.enabled -}}
{{- .Values.clickhouse.service.ports.tcp | default 9000 }}
{{- else -}}
{{- .Values.clickhouse.external.port | default 9000 }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.clickhouse.httpPort" -}}
{{- if .Values.clickhouse.enabled -}}
{{- .Values.clickhouse.service.ports.http | default 8123 }}
{{- else -}}
{{- .Values.clickhouse.external.httpPort | default 8123 }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.clickhouse.username" -}}
{{- if .Values.clickhouse.enabled -}}
{{- .Values.clickhouse.auth.username | default "root" }}
{{- else -}}
{{- .Values.clickhouse.external.username | default "default" }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.clickhouse.password" -}}
{{- if .Values.clickhouse.enabled -}}
{{- .Values.clickhouse.auth.password | default "shimo" }}
{{- else -}}
{{- .Values.clickhouse.external.password }}
{{- end -}}
{{- end -}}

{{- define "clickvisual-stack.clickhouse.dsn" -}}
{{- $host := include "clickvisual-stack.clickhouse.host" . -}}
{{- $port := include "clickvisual-stack.clickhouse.port" . -}}
{{- $user := include "clickvisual-stack.clickhouse.username" . -}}
{{- $pass := include "clickvisual-stack.clickhouse.password" . -}}
{{- printf "tcp://%s:%v?username=%s&password=%s&read_timeout=10&write_timeout=10&debug=true" $host $port $user $pass }}
{{- end -}}

{{- define "clickvisual-stack.clickhouse.dsn.http" -}}
{{- $host := include "clickvisual-stack.clickhouse.host" . -}}
{{- $port := include "clickvisual-stack.clickhouse.httpPort" . -}}
{{- $user := include "clickvisual-stack.clickhouse.username" . -}}
{{- $pass := include "clickvisual-stack.clickhouse.password" . -}}
{{- $db := .Values.clickhouse.external.database | default "default" }}
{{- printf "clickhouse://%s:%s@%s:%v/%s?max_execution_time=60" $user $pass $host $port $db }}
{{- end -}}

{{/*
===========================================
Kafka Connection Helpers
===========================================
*/}}
{{- define "clickvisual-stack.kafka.brokers" -}}
{{- if .Values.kafka.enabled -}}
{{- printf "%s-kafka:%v" .Release.Name (.Values.kafka.service.port | default 9092) }}
{{- else -}}
{{- join "," .Values.kafka.external.brokers }}
{{- end -}}
{{- end -}}

{{/*
===========================================
Service Account Name
===========================================
*/}}
{{- define "clickvisual-stack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "clickvisual-stack.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
