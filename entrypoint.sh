#!/bin/sh
set -eu

mkdir -p /app/logs

# OpenTelemetry Java agent (configurable via env)
JAVA_AGENT=/opt/otel/opentelemetry-javaagent.jar
OTEL_SERVICE_NAME=${OTEL_SERVICE_NAME:-eda-backend}
OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT:-http://apm-server:8200}
OTEL_EXPORTER_OTLP_PROTOCOL=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf}
ENABLE_OTEL=${ENABLE_OTEL:-true}

# Esperas robustas de dependencias
WAIT_RETRIES=${WAIT_RETRIES:-60}
WAIT_SLEEP=${WAIT_SLEEP:-2}

wait_tcp() {
  host="$1"; port="$2"; name="$3"; retries=${4:-$WAIT_RETRIES}
  i=1
  echo "[wait] Esperando ${name} en ${host}:${port} (max ${retries} intentos)"
  while [ "$i" -le "$retries" ]; do
    if nc -z "$host" "$port" 2>/dev/null; then
      echo "[wait] ${name} disponible"
      return 0
    fi
    i=$((i+1))
    sleep "$WAIT_SLEEP"
  done
  echo "[wait] ERROR: ${name} no disponible tras ${retries} intentos" >&2
  return 1
}

wait_http() {
  url="$1"; name="$2"; retries=${3:-$WAIT_RETRIES}
  i=1
  echo "[wait] Esperando ${name} en ${url}"
  while [ "$i" -le "$retries" ]; do
    if curl -sf "$url" >/dev/null 2>&1; then
      echo "[wait] ${name} disponible"
      return 0
    fi
    i=$((i+1))
    sleep "$WAIT_SLEEP"
  done
  echo "[wait] WARNING: ${name} no respondió HTTP; continúo" >&2
  return 1
}

# Esperar DB vía HAProxy (master)
wait_tcp "haproxy" 5000 "Postgres via HAProxy" || true

# Esperar Kafka al menos broker principal
wait_tcp "kafka" 9092 "Kafka broker kafka" || true
# En stack simplificado no hay brokers secundarios

# Esperar APM Server (OTLP HTTP) solo si OTEL está habilitado
if [ "$ENABLE_OTEL" = "true" ]; then
  wait_http "${OTEL_EXPORTER_OTLP_ENDPOINT}" "APM Server" || true
fi

if [ "$ENABLE_OTEL" = "true" ] && [ -f "$JAVA_AGENT" ]; then
  JAVA_OPTS="${JAVA_OPTS} -javaagent:${JAVA_AGENT}"
  JAVA_OPTS="${JAVA_OPTS} -Dotel.service.name=${OTEL_SERVICE_NAME} -Dotel.exporter.otlp.endpoint=${OTEL_EXPORTER_OTLP_ENDPOINT} -Dotel.exporter.otlp.protocol=${OTEL_EXPORTER_OTLP_PROTOCOL}"
  JAVA_OPTS="${JAVA_OPTS} -Dotel.traces.exporter=otlp -Dotel.metrics.exporter=otlp -Dotel.logs.exporter=otlp"
fi

exec java ${JAVA_OPTS} -Xms256m -Xmx512m -jar /app/app.jar