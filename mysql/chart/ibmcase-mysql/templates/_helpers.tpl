{{- define "mysqlDataVolume" -}}
        - name: {{ .Values.dbname }}-mysql
{{- if .Values.global.persistenceEnabled }}
          persistentVolumeClaim:
    {{- if .Values.existingPVCName }}
            claimName: {{ .Values.existingPVCName }}
    {{- else }}
            claimName: {{ .Release.Name }}-{{ .Chart.Name }}-{{ .Values.dbname }}-data
    {{- end -}}
{{ else }}
          hostPath:
            path: /var/lib/mysql-{{ .Values.dbname }}
{{ end }}
{{- end -}}
