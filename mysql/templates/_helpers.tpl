{{- define "mysql.fullname" -}}
{{- printf "%s-%s" .Release.Name .Values.service.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mySQLDockerImage" -}}
  {{- .Values.image.repository }}
{{- end -}}

{{- define "busyBoxDockerImage" -}}
  {{- .Values.busybox.image.repository }}
{{- end -}}

{{- define "mysqlVolumeSize" -}}
  {{- if .Values.persistence.size -}}
    {{ .Values.persistence.size }}
  {{- else if .Values.global.persistence.volume.size -}}
    {{ .Values.global.persistence.volume.size }}
  {{- else -}}
    {{- printf "10Gi" -}}
  {{- end -}}
{{- end -}}

{{- define "mysqlVolumeStorageClass" -}}
  {{- if .Values.persistence.storageClass -}}
    {{ .Values.persistence.storageClass }}
  {{- else if .Values.global.persistence.volume.storageClass -}}
    {{ .Values.global.persistence.volume.storageClass }}
  {{- else -}}
    {{- printf "" -}}
  {{- end -}}
{{- end -}}

{{- define "mysqlDataVolume" -}}
        - name: data
  {{- if (or .Values.persistence.enabled .Values.global.persistence.enabled) }}
          persistentVolumeClaim:
            claimName: {{ .Values.persistence.existingClaim | default (include "mysql.fullname" .) }}
  {{- else }}
          emptyDir: {}
  {{- end -}}
{{- end -}}
