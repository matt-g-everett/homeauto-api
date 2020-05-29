{{/* version: 1.0.0 */}}

{{/*
Replica count for basic HA microservices (normally matches the minHA)
*/}}
{{- define "homeauto-api.replicaCount.basicHA" -}}
    {{- if hasKey .Values "replicaCountOverride" -}}
        {{ .Values.replicaCountOverride }}
    {{- else if hasKey .Values.global "minHA" -}}
        {{ .Values.global.minHA }}
    {{- else -}}
        {{ .Values.replicaCount }}
    {{- end -}}
{{- end -}}

{{/*
Use local override of the replicaCount if one is provided; otherwise, use the global replicaCount.
*/}}
{{- define "homeauto-api.replicaCount.single" -}}
    {{- if hasKey .Values "replicaCountOverride" -}}
        {{ .Values.replicaCountOverride }}
    {{- else -}}
        1
    {{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "homeauto-api.name" -}}
    {{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.

If the release name is the same as the product name, don't prepend the release name,
this is useful for preventing the release name prefix in a hierarchical chart.
*/}}
{{- define "homeauto-api.fullname" -}}
    {{- if .Values.fullnameOverride -}}
        {{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
    {{- else -}}
        {{- $name := default .Chart.Name .Values.nameOverride -}}
        {{- if eq .Release.Name .Values.global.productName -}}
            {{- $name | trunc 63 | trimSuffix "-" -}}
        {{- else if contains $name .Release.Name -}}
            {{- .Release.Name | trunc 63 | trimSuffix "-" -}}
        {{- else -}}
            {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{/*
Create domain for the supplied service comms entry, based on whether the comms entry specifies a namespace.

By default, the domain is empty. If a namespace is specified in the comms entry, then the fully qualified domain
is generated.

Accepts a dict with keys: -
- g: global scope (set to $)
- commsEntry: entry from the .Values.global.comms object

Example usage: -

  alarm{{ template "homeauto-api.domain" (dict "g" $ "commsEntry" .Values.global.comms.alarm) }}

Output of the example above would either be: -

  - alarm (empty string when namespace is not set in comms entry), or
  - alarm.mediakind.svc.cluster.local (namespace + cluster domain when namespace is set to 'mediakind' in comms entry).
*/}}
{{- define "homeauto-api.domain" -}}
    {{- if (hasKey .commsEntry "namespace") -}}
        .{{ .commsEntry.namespace }}.{{ .g.Values.global.clusterDomain }}
    {{- end -}}
{{- end -}}

{{/*
Allow the service name to be overridden independently of the fullnameOverride.
*/}}
{{- define "homeauto-api.serviceName" -}}
    {{- $serviceName := "" -}}
    {{- if hasKey .Values "service" -}}
        {{- if hasKey .Values.service "name" -}}
            {{- $serviceName = .Values.service.name -}}
        {{- end -}}
    {{- end -}}

    {{- if $serviceName -}}
        {{- $serviceName -}}
    {{- else -}}
        {{- template "homeauto-api.fullname" . -}}
    {{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "homeauto-api.chart" -}}
    {{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" | trimSuffix "." -}}
{{- end -}}

{{/*
Construct the location of specific image.

Pass a dict containing keys: -
- g: global scope (set to $)
- image

Where "image" is an object that contains: -
- repository
- tag
- registryOverride (optional)

Example usage: -
{{ template "homeauto-api.specificImage" (dict "g" $ "image" .Values.serverDaemonImage) }}
*/}}
{{- define "homeauto-api.specificImage" -}}
    {{- $registry := first (splitList "/" .image.repository) -}}
    {{- $imageLocation := (splitn "/" 2 .image.repository)._1 -}}
    {{- if hasKey .g.Values.global "image" -}}
        {{- if hasKey .g.Values.global.image "registryOverride" -}}
            {{- $registry = .g.Values.global.image.registryOverride -}}
        {{- end -}}

        {{- if hasKey .g.Values.global.image "flatRepo" -}}
            {{- if .g.Values.global.image.flatRepo -}}
                {{- $imageLocation = last (splitList "/" .image.repository) -}}
            {{- end -}}
        {{- end -}}
    {{- end -}}

    {{- if hasKey .image "registryOverride" -}}
        {{- $registry = .image.registryOverride -}}
    {{- end -}}

    {{- $registry -}}/{{ $imageLocation }}:{{ .image.tag -}}
{{- end -}}

{{/*
Construct the image location for the primary container in the chart.

This is a convenience wrapper around the homeauto-api.specificImage template.
*/}}
{{- define "homeauto-api.image" -}}
    {{- template "homeauto-api.specificImage" (dict "g" . "image" .Values.image) -}}
{{- end -}}

{{/*
Determine the most appropriate image pull policy for a specific image.

Pass a dict containing keys: -
- g: global scope (set to $)
- image

Where "image" contains: -
- tag
- pullPolicy (optional)

Example usage: -
{{ template "homeauto-api.specificImagePullPolicy" (dict "g" $ "image" .Values.serverDaemonImage) }}
*/}}
{{- define "homeauto-api.specificImagePullPolicy" -}}
    {{- $globalImagePullPolicy := "" -}}
    {{- if hasKey .g.Values.global "image" -}}
        {{- if hasKey .g.Values.global.image "imagePullPolicyOverride" -}}
            {{- $globalImagePullPolicy = .g.Values.global.image.imagePullPolicyOverride -}}
        {{- end -}}
    {{- end -}}

    {{- if $globalImagePullPolicy -}}
        {{- $globalImagePullPolicy -}}
    {{- else if (hasKey .image "pullPolicy") -}}
        {{- .image.pullPolicy -}}
    {{- else if (eq .image.tag "latest") -}}
        Always
    {{- else -}}
        IfNotPresent
    {{- end -}}
{{- end -}}

{{/*
Determine the most appropriate image pull policy for the primary container in the chart.

This is a convenience wrapper around the homeauto-api.specificImagePullPolicy template.
*/}}
{{- define "homeauto-api.imagePullPolicy" -}}
    {{- template "homeauto-api.specificImagePullPolicy" (dict "g" . "image" .Values.image) -}}
{{- end -}}

{{/*
Create the standard role name.
*/}}
{{- define "homeauto-api.roleName" -}}
    {{- if hasKey .Values.rbac "roleName" -}}
        {{- .Values.rbac.roleName -}}
    {{- else -}}
        {{- include "homeauto-api.fullname" . -}}
    {{- end -}}
{{- end -}}

{{/*
Create the standard role binding name.
*/}}
{{- define "homeauto-api.roleBindingName" -}}
    {{- if hasKey .Values.rbac "roleBindingName" -}}
        {{- .Values.rbac.roleBindingName -}}
    {{- else -}}
        {{- include "homeauto-api.fullname" . -}}
    {{- end -}}
{{- end -}}

{{/*
Create the service account name.
*/}}
{{- define "homeauto-api.serviceAccountName" -}}
    {{- if hasKey .Values.serviceAccount "name" -}}
        {{- .Values.serviceAccount.name -}}
    {{- else -}}
        {{- include "homeauto-api.fullname" . -}}
    {{- end -}}
{{- end -}}

{{/*
Standard template for including environment variables from local and global values.
*/}}
{{- define "homeauto-api.envvars.passthru" -}}
    {{- if .Values.env }}
# Chart environment variables
{{ toYaml .Values.env | trim }}
    {{- end -}}
    {{- if .Values.global.env }}
# Global environment variables
{{ toYaml .Values.global.env | trim }}
    {{- end -}}
{{- end -}}

{{/*
Standard template for including resources.
*/}}
{{- define "homeauto-api.resources" -}}
    {{- if .Values.resources }}
{{ toYaml .Values.resources | trim }}
    {{- end -}}
{{- end -}}

{{/*
Standard template for including environment variables for MongoDB comms info.
*/}}
{{- define "homeauto-api.envvars.mongo" -}}
- { name: MONGO_SERVER_ADDR, value: {{ include "homeauto-api.mongo.url" . | quote }} }
- { name: MONGO_REPLICA, value: {{ if .Values.global.comms.mongo.replicaSetName }}"true"{{ else }}"false"{{ end }} }
- { name: MONGO_REPLICA_NAME, value: {{ .Values.global.comms.mongo.replicaSetName | quote }} }
{{- end -}}

{{/*
Standard template for including affinity, toleration and nodeSelector rules.
*/}}
{{- define "homeauto-api.affinity" -}}
    {{- if .Values.affinity }}
affinity:
{{ toYaml .Values.affinity | trim | indent 2 -}}
    {{- else if .Values.global.affinity }}
affinity:
{{ toYaml .Values.global.affinity | trim | indent 2 -}}
    {{- end -}}

    {{- if .Values.tolerations }}
tolerations:
{{ toYaml .Values.tolerations | trim }}
    {{- else if .Values.global.tolerations }}
tolerations:
{{ toYaml .Values.global.tolerations | trim }}
    {{- end -}}

    {{- if .Values.nodeSelector }}
nodeSelector:
{{ toYaml .Values.nodeSelector | trim | indent 2 }}
    {{- else if .Values.global.nodeSelector }}
nodeSelector:
{{ toYaml .Values.global.nodeSelector | trim | indent 2 }}
    {{- end -}}
{{- end -}}

{{/*
Standard template for including labels.
*/}}
{{- define "homeauto-api.labels" -}}
app.kubernetes.io/name: {{ template "homeauto-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/component: homeauto-api
app.kubernetes.io/part-of: {{ .Values.global.productName }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ template "homeauto-api.chart" . }}
{{- range $key, $value := .Values.additionalLabels }}
{{ printf "%s: %s" $key $value }}
{{- end }}
{{- end -}}

{{/*
Standard template for including selectors.
*/}}
{{- define "homeauto-api.selectors" -}}
app.kubernetes.io/name: {{ template "homeauto-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Construct the mongo address with or without the port.

Normally, this template should not be used directly, it's simpler to use: -
- homeauto-api.mongo.fullUrl.xxxxDB - for the full mongo URL with a standard DB, e.g.
  mongo://mongodb-replicaset-0.mongodb-replicaset:27017,mongodb-replicaset-1.mongodb-replicaset:27017,mongodb-replicaset-2.mongodb-replicaset:27017/envivioCluster?replicaSet=rs0
- homeauto-api.mongo.fullUrl - for the full mongo URL with product-specific DB, e.g.
  mongo://mongodb-replicaset-0.mongodb-replicaset:27017,mongodb-replicaset-1.mongodb-replicaset:27017,mongodb-replicaset-2.mongodb-replicaset:27017/myProductDB?replicaSet=rs0
- homeauto-api.mongo.url - for the URL address with the host names and ports (but no protocol or DB), e.g.
  mongodb-replicaset-0.mongodb-replicaset:27017,mongodb-replicaset-1.mongodb-replicaset:27017,mongodb-replicaset-2.mongodb-replicaset:27017
- homeauto-api.mongo.host - for the URL address with only the host names (no protocol, port or DB), e.g.
  mongodb-replicaset-0.mongodb-replicaset,mongodb-replicaset-1.mongodb-replicaset,mongodb-replicaset-2.mongodb-replicaset

Accepts a dict with keys: -
- g: global scope (set to $)
- addPort: boolean to indicate whether the port should be included

Example usage: -
{{ template "homeauto-api.mongo.connectionInfo" (dict "g" $ "addPort" true) }}
*/}}
{{- define "homeauto-api.mongo.connectionInfo" -}}
    {{- $mongoComms := .g.Values.global.comms.mongo -}}
    {{- $dm := include "homeauto-api.domain" (dict "g" .g "commsEntry" $mongoComms) }}
    {{- $releasePrefix := "" -}}
    {{- if hasKey $mongoComms "release" -}}
        {{- $releasePrefix = (printf "%s-" $mongoComms.release) -}}
    {{- end -}}
    {{- $serviceName := printf "%s%s" $releasePrefix $mongoComms.name }}
    {{- $prefix := printf "%s-" $serviceName -}}
    {{- $port := "" -}}
    {{- if .addPort -}}
        {{- $port = printf ":%.0f" $mongoComms.port -}}
    {{- end -}}
    {{- $postfix := printf ".%s%s%s" $serviceName $dm $port -}}
    {{- $replicas := int $mongoComms.replicas }}
    {{- range $index, $element := until $replicas -}}
        {{- if $index }},{{ end -}}
        {{- $prefix }}{{ $index }}{{ $postfix -}}
    {{- end }}
{{- end -}}

{{/*
Construct the mongo connection address including the port number based on the members in the replicaset.

Output example: -
mongodb-replicaset-0.mongodb-replicaset:27017,mongodb-replicaset-1.mongodb-replicaset:27017,mongodb-replicaset-2.mongodb-replicaset:27017
*/}}
{{- define "homeauto-api.mongo.url" -}}
    {{- template "homeauto-api.mongo.connectionInfo" (dict "g" . "addPort" true) -}}
{{- end -}}

{{/*
Construct the mongo host address without the port number based on the members in the replicaset.

Output example: -
mongodb-replicaset-0.mongodb-replicaset,mongodb-replicaset-1.mongodb-replicaset,mongodb-replicaset-2.mongodb-replicaset
*/}}
{{- define "homeauto-api.mongo.host" -}}
    {{- template "homeauto-api.mongo.connectionInfo" (dict "g" . "addPort" false) -}}
{{- end -}}

{{/*
Construct the full MongoDB URL for the specified database.

If using one of the standard DBs, prefer to use the homeauto-api.mongo.fullUrl.xxxxDB templates.

Accepts a dict with keys: -
- g: global scope (set to $)
- dbName: name of the database

Example usage: -
{{ template "homeauto-api.mongo.fullUrl" (dict "g" $ "dbName" "myProductDB") }}

Output example: -
mongo://mongodb-replicaset-0.mongodb-replicaset:27017,mongodb-replicaset-1.mongodb-replicaset:27017,mongodb-replicaset-2.mongodb-replicaset:27017/myProductDB?replicaSet=rs0
*/}}
{{- define "homeauto-api.mongo.fullUrl" -}}
    {{- $rsName := .g.Values.global.comms.mongo.replicaSetName -}}
    {{- if $rsName }}
        {{- printf "mongodb://%s/%s?replicaSet=%s" (include "homeauto-api.mongo.url" .g) .dbName $rsName }}
    {{- else }}
        {{- printf "mongodb://%s/%s" (include "homeauto-api.mongo.url" .g) .dbName }}
    {{- end}}
{{- end -}}

{{/*
Construct the MongoDB URL for the Alarm Database (alarm)

Output example: -
mongo://mongodb-replicaset-0.mongodb-replicaset:27017,mongodb-replicaset-1.mongodb-replicaset:27017,mongodb-replicaset-2.mongodb-replicaset:27017/alarm?replicaSet=rs0
*/}}
{{- define "homeauto-api.mongo.fullUrl.alarmDB" -}}
    {{- template "homeauto-api.mongo.fullUrl" (dict "g" . "dbName" "alarm") -}}
{{- end -}}

{{/*
Construct the MongoDB URL for the Cluster Database (envivioCluster)

Output example: -
mongo://mongodb-replicaset-0.mongodb-replicaset:27017,mongodb-replicaset-1.mongodb-replicaset:27017,mongodb-replicaset-2.mongodb-replicaset:27017/envivioCluster?replicaSet=rs0
*/}}
{{- define "homeauto-api.mongo.fullUrl.clusterDB" -}}
    {{- template "homeauto-api.mongo.fullUrl" (dict "g" . "dbName" "envivioCluster") -}}
{{- end -}}

{{/*
Construct the MongoDB URL for the Global Mutex Lock Database (mediakindMongolock).

Output example: -
mongo://mongodb-replicaset-0.mongodb-replicaset:27017,mongodb-replicaset-1.mongodb-replicaset:27017,mongodb-replicaset-2.mongodb-replicaset:27017/mediakindMongolock?replicaSet=rs0
*/}}
{{- define "homeauto-api.mongo.fullUrl.lockDB" -}}
    {{- template "homeauto-api.mongo.fullUrl" (dict "g" . "dbName" "mediakindMongolock") -}}
{{- end -}}

{{/*
Custom /var/run folder path for specific components that are not the primary microservice.

Accepts a the name of the microservice that will be incorporated into the /var/run path.

Example usage: -
{{ template "homeauto-api.specificVarRunPath" "my-sidecar" }}
*/}}
{{- define "homeauto-api.specificVarRunPath" -}}
    /var/run/ericsson/{{ . }}
{{- end -}}

{{/*
Get path to component-specific /var/run folder
Mostly used for ready file for components without readiness REST endpoints
*/}}
{{- define "homeauto-api.varRunPath" -}}
    {{- template "homeauto-api.specificVarRunPath" "homeauto-api" -}}
{{- end -}}

{{/*
Construct the K8s service name (DNS name) for the specified microservice.

Accepts a dict with keys: -
- g: global scope (set to $)
- commsEntry: entry from the .Values.global.comms object

Example usage: -
{{ template "homeauto-api.comms.serviceName" (dict "g" $ "commsEntry" .Values.global.comms.alarm) }}
*/}}
{{- define "homeauto-api.comms.serviceName" -}}
    {{- $releasePrefix := "" -}}
    {{- if hasKey .commsEntry "release" -}}
        {{- $releasePrefix = (printf "%s-" .commsEntry.release) -}}
    {{- end -}}

    {{- $releasePrefix }}{{ .commsEntry.name }}{{ template "homeauto-api.domain" . }}
{{- end -}}

{{/*
Construct the K8s service address (DNS name + port) name for the specified microservice.

Accepts a dict with keys: -
- g: global scope (set to $)
- commsEntry: entry from the .Values.global.comms object

Example usage: -
{{ template "homeauto-api.comms.address" (dict "g" $ "commsEntry" .Values.global.comms.alarm) }}
*/}}
{{- define "homeauto-api.comms.address" -}}
    {{- template "homeauto-api.comms.serviceName" . -}}:{{- .commsEntry.port -}}
{{- end -}}

{{- define "homeauto-api.hostNetwork" -}}
    {{- if hasKey .Values "hostNetwork" -}}
        {{ .Values.hostNetwork }}
    {{- else -}}
        false
    {{- end -}}
{{- end -}}

{{- define "homeauto-api.dnsPolicy" -}}
    {{- if hasKey .Values "dnsPolicy" -}}
        {{ .Values.dnsPolicy }}
    {{- else if (eq (include "homeauto-api.hostNetwork" .) "true") -}}
        ClusterFirstWithHostNet
    {{- else -}}
        ClusterFirst
    {{- end -}}
{{- end -}}

{{- define "homeauto-api.rollingUpdateConfig" -}}
    {{- if (eq (include "homeauto-api.hostNetwork" .) "true") -}}
        {maxSurge: 0, maxUnavailable: 1}
    {{- else -}}
        {maxSurge: 1, maxUnavailable: 0}
    {{- end -}}
{{- end -}}
