#!/usr/bin/env bash
set -euo pipefail
for t in payments.events transfers.events alerts.suspect; do
  echo "Creating topic: $t"
  docker exec -i kafka kafka-topics.sh --bootstrap-server kafka:9092 --create --if-not-exists --topic $t --partitions 3 --replication-factor 1 || true
done
echo "Done."
