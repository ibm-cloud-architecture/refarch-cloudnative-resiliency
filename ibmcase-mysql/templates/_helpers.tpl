{{- define "mysql.fullname" -}}
{{- printf "%s-%s" .Release.Name .Values.service.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mySQLDockerImage" -}}
  {{- .Values.image.repository }}
{{- end -}}

{{- define "busyBoxDockerImage" -}}
  {{- .Values.busybox.image.repository }}
{{- end -}}