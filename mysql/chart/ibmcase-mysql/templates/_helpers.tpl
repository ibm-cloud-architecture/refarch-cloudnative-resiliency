{{- define "mysqlDataVolume" -}}
        - name: {{ .Values.dbname }}-mysql
{{- if .Values.global.persistence.enabled }}
          persistentVolumeClaim:
    {{- if .Values.persistence.existingName }}
            claimName: {{ .Values.persistence.existingName }}
    {{- else }}
            claimName: {{ .Release.Name }}-{{ .Chart.Name }}-{{ .Values.dbname }}-data
    {{- end -}}
{{- else if .Values.persistence.enabled }}
          persistentVolumeClaim:
    {{- if .Values.persistence.existingName }}
            claimName: {{ .Values.persistence.existingName }}
    {{- else }}
            claimName: {{ .Release.Name }}-{{ .Chart.Name }}-{{ .Values.dbname }}-data
    {{- end -}}
{{ else }}
          hostPath:
            path: /var/lib/mysql-{{ .Values.dbname }}
{{ end }}
{{- end -}}

{{- define "volumeSize" -}}
  {{- if .Values.persistence.volume.size -}}
    {{ .Values.persistence.volume.size }}
  {{- else if .Values.global.persistence.volume.size -}}
    {{ .Values.global.persistence.volume.size }}
  {{- else -}}
    {{- printf "20Gi" -}}
  {{- end -}}
{{- end -}}

{{- define "volumeStorageClass" -}}
  {{- if .Values.persistence.volume.storageClass -}}
    {{ .Values.persistence.volume.storageClass }}
  {{- else if .Values.global.persistence.volume.storageClass -}}
    {{ .Values.global.persistence.volume.storageClass }}
  {{- else -}}
    {{- printf "" -}}
  {{- end -}}
{{- end -}}
