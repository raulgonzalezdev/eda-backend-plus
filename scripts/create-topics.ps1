param(
  [string]$BootstrapServers = "localhost:9092",
  [string]$KafkaHome = $env:KAFKA_HOME
)

if (-not $KafkaHome) {
  Write-Error "KAFKA_HOME no está definido. Establece KAFKA_HOME a la carpeta de Kafka (ej: C:\Kafka\kafka_2.13-3.7.0)."
  exit 1
}

$kafkaTopicsBat = Join-Path $KafkaHome "bin\windows\kafka-topics.bat"
if (-not (Test-Path $kafkaTopicsBat)) {
  Write-Error "No se encontró kafka-topics.bat en '$kafkaTopicsBat'. Verifica KAFKA_HOME."
  exit 1
}

$topics = @(
  "payments.events",
  "transfers.events",
  "alerts.suspect"
)

foreach ($t in $topics) {
  Write-Host "Creando tópico '$t' en $BootstrapServers" -ForegroundColor Cyan
  & $kafkaTopicsBat --create --if-not-exists --topic $t --bootstrap-server $BootstrapServers --replication-factor 1 --partitions 1
}

Write-Host "Tópicos verificados/creados correctamente." -ForegroundColor Green