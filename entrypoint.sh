#!/bin/sh

# Esperar a que la base de datos esté lista
until nc -z -v -w30 haproxy 5000
do
  echo "Esperando a que la base de datos esté disponible..."
  sleep 1
done

# Ejecutar la aplicación
exec java -jar app.jar