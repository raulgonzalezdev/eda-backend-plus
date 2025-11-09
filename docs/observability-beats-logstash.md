# Observabilidad: Beats y Logstash (esbozo de configuración)

Este documento prepara, sin ejecutarlo, la configuración para:
- Filebeat: capturar logs de contenedores Docker y enviarlos a Elasticsearch/Kibana.
- Logstash: consumir eventos `alerts.suspect` desde Kafka, enriquecerlos y escribir en `alerts.enriched-*`.

## Estructura añadida
- `docker-compose.observability-extras.yml`: compose separado para Filebeat y Logstash.
- `config/beats/filebeat.yml`: configuración de Filebeat.
- `config/logstash/pipelines.yml`: definición de pipelines.
- `config/logstash/logstash.yml`: configuración base de Logstash.
- `config/logstash/pipeline/alerts_enriched.conf`: pipeline de enriquecimiento.

## Filebeat
- Entrada: `/var/lib/docker/containers/*/*-json.log` (logs de contenedores).
- Salida: `output.elasticsearch` con credenciales de dev (`elastic/changeme`).
- Kibana: `setup.kibana` para dashboards preconstruidos (opcional).

Ejemplo de config: `config/beats/filebeat.yml`.

## Logstash (pipeline `alerts_enriched`)
- Input: Kafka `alerts.suspect` (`kafka:9092`).
- Filter: añade `pipeline: alerts_enriched` y `risk_level` según `payload.amount` (>= 10000 ⇒ high).
- Output: Elasticsearch índice diario `alerts.enriched-YYYY.MM.dd`.

Pipeline: `config/logstash/pipeline/alerts_enriched.conf`.

## Compose separado (no ejecutar ahora)
- Archivo: `docker-compose.observability-extras.yml`.
- Reutiliza `kafka-network` como red externa (compartida con tu stack actual).
- Servicios: `filebeat` y `logstash`, ambos con variables y volúmenes montados.

## Cómo levantarlo post-entrevista (opcional)
1. Construir/validar que tu stack principal corre (ES, Kibana, Kafka).
2. Levantar extras:
   - `docker compose -f docker-compose.observability-extras.yml up -d`
3. Validar:
   - Discover: ver `logs-*`.
   - Índice enriquecido: `alerts.enriched-*` en Elasticsearch/Kibana.
   - Reglas en Kibana: “Index threshold” sobre `alerts.enriched-*`.

## Notas de seguridad y buenas prácticas
- Dev: credenciales `elastic/changeme` son sólo para local.
- Prod: usar Service Accounts / API Keys de alcance mínimo.
- Gestionar retención y tamaño de índices (`ILM`) para logs y alertas.

---

Documentos relacionados:
- `docs/observability-overview.md` (visión general APM/OTel)
- `docs/apm-permissions-guide.md` (permisos y roles APM)
- `docs/apm-test-verify.md` (pruebas y verificación)