#!/bin/sh
set -x

# Create a logs directory if it doesn't exist
mkdir -p /app/logs

# Start the application
exec java -Xms256m -Xmx512m -jar /app/app.jar