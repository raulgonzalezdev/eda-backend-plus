#!/bin/sh
set -x

# Create a logs directory if it doesn't exist
mkdir -p /app/logs

# Start the application with OpenTelemetry Java agent (configurable via env)
JAVA_AGENT=/opt/otel/opentelemetry-javaagent.jar

# Defaults can be overridden by environment variables
OTEL_SERVICE_NAME=${OTEL_SERVICE_NAME:-eda-backend}
OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT:-http://apm-server:8200}
OTEL_EXPORTER_OTLP_PROTOCOL=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/protobuf}
ENABLE_OTEL=${ENABLE_OTEL:-true}

if [ "$ENABLE_OTEL" = "true" ] && [ -f "$JAVA_AGENT" ]; then
  JAVA_OPTS="${JAVA_OPTS} -javaagent:${JAVA_AGENT}"
  JAVA_OPTS="${JAVA_OPTS} -Dotel.service.name=${OTEL_SERVICE_NAME} -Dotel.exporter.otlp.endpoint=${OTEL_EXPORTER_OTLP_ENDPOINT} -Dotel.exporter.otlp.protocol=${OTEL_EXPORTER_OTLP_PROTOCOL}"
  JAVA_OPTS="${JAVA_OPTS} -Dotel.traces.exporter=otlp -Dotel.metrics.exporter=otlp -Dotel.logs.exporter=otlp"
fi

exec java ${JAVA_OPTS} -Xms256m -Xmx512m -jar /app/app.jar