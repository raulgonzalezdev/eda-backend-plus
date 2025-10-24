#!/usr/bin/env bash
set -euo pipefail
for t in payments.events transfers.events alerts.suspect; do
  echo "Creating topic: $t"
  docker exec -i kafka-cli kafka-topics --bootstrap-server kafka:9092 --create --if-not-exists --topic $t --partitions 6 --replication-factor 3 || true
done
echo "Done."
