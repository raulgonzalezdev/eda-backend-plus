# Balanceador de Carga NGINX - EDA Backend Plus

## Navegación
- Inicio: [README](../README.md)
- Metodología: [Metodologia.md](Metodologia.md)
- Observabilidad (APM/OTel): [observability-overview.md](observability-overview.md)
- Resiliencia BD (Patroni + HAProxy): [database-resilience.md](database-resilience.md)
- Balanceador NGINX: [README-LoadBalancer.md](README-LoadBalancer.md)
- Guía de entrevista: [guia-entrevista-backend.md](guia-entrevista-backend.md)
- Contribución (ES): [CONTRIBUTING.es.md](CONTRIBUTING.es.md)
- Contribución (EN): [CONTRIBUTING.md](CONTRIBUTING.md)
- Esquema POS y DDL: [pos_schema_instructions.md](pos_schema_instructions.md)
- OpenAPI: [../specs/openapi.yaml](../specs/openapi.yaml) · AsyncAPI: [../specs/asyncapi.yaml](../specs/asyncapi.yaml)

## Resumen de Implementación

Este documento describe la implementación exitosa de un balanceador de carga NGINX con alta disponibilidad y failover automático para la aplicación EDA Backend Plus.

## Arquitectura Implementada

### Componentes
- **3 Instancias de Aplicación**: `eda-backend-app1`, `eda-backend-app2`, `eda-backend-app3`
- **Balanceador NGINX**: `nginx-load-balancer`
- **Health Checks**: Verificación automática de salud en `/api/health`
- **Failover Automático**: Recuperación automática ante fallos

### Puertos de Acceso
- **Puerto 80**: Acceso HTTP estándar
- **Puerto 8085**: Acceso HTTP alternativo (mapeado desde 8080 interno)
- **Puerto 8090**: Puerto para métricas y monitoreo

## 🔧 Componentes Implementados

### 1. **Múltiples Instancias de Aplicación**
- **app1**: Puerto 8081 (eda-backend-app1)
- **app2**: Puerto 8082 (eda-backend-app2)  
- **app3**: Puerto 8083 (eda-backend-app3)

### 2. **NGINX Load Balancer**
- **Puerto 80**: Acceso principal
- **Puerto 8080**: Compatibilidad con configuración anterior
- **Puerto 8090**: Métricas y monitoreo

### 3. **Health Checks Automáticos**
- **Docker Health Checks**: Cada 30 segundos
- **NGINX Health Checks**: Automáticos con failover
- **Endpoint**: `/api/health`

## ⚙️ Configuración

### **Docker Compose**
```yaml
# 3 instancias de la aplicación
app1, app2, app3:
  - Puertos: 8081, 8082, 8083
  - Health checks cada 30s
  - Restart automático
  - Variables de entorno individuales

# NGINX Load Balancer
nginx:
  - Puertos: 80, 8080, 8090
  - Configuración en ./nginx/nginx.conf
  - Dependencias: app1, app2, app3
```

### **NGINX Configuration**
```nginx
upstream eda_backend {
    least_conn;  # Balanceo por menor conexiones
    server app1:8080 max_fails=3 fail_timeout=30s;
    server app2:8080 max_fails=3 fail_timeout=30s;
    server app3:8080 max_fails=3 fail_timeout=30s;
}
```

## 🚀 Cómo Usar

### **1. Iniciar el Sistema**
```powershell
# Construir y levantar todos los servicios
docker-compose up --build -d

# Verificar estado de los contenedores
docker-compose ps
```

### **2. Verificar el Balanceador**
```powershell
# Probar el endpoint principal
curl http://localhost/api/health

# Probar múltiples requests para ver distribución
for ($i=1; $i -le 10; $i++) { 
    curl http://localhost/api/health 
}
```

### **3. Ejecutar Pruebas Automatizadas**
```powershell
# Prueba básica del balanceador
.\scripts\test_load_balancer.ps1

# Prueba con failover simulado
.\scripts\test_load_balancer.ps1 -TestFailover

# Prueba detallada con más requests
.\scripts\test_load_balancer.ps1 -Requests 50 -Verbose
```

## 🔍 Monitoreo y Métricas

### **Endpoints de Monitoreo**
- `http://localhost/health` - Health check del balanceador
- `http://localhost/api/health` - Health check de las aplicaciones
- `http://localhost:8090/metrics` - Métricas de NGINX
- `http://localhost/nginx-status` - Estado de NGINX

### **Logs**
```powershell
# Ver logs del balanceador
docker logs nginx-load-balancer

# Ver logs de una instancia específica
docker logs eda-backend-app1

# Ver logs de todas las instancias
docker-compose logs app1 app2 app3
```

## 🛠️ Características del Balanceador

### **Estrategias de Balanceo**
- ✅ **Least Connections**: Dirige tráfico a la instancia con menos conexiones activas
- ✅ **Health Checks**: Verifica automáticamente la salud de cada instancia
- ✅ **Failover Automático**: Redirige tráfico si una instancia falla
- ✅ **Auto-recovery**: Reintegra instancias cuando se recuperan

### **Configuración de Failover**
- **max_fails**: 3 intentos fallidos antes de marcar como down
- **fail_timeout**: 30 segundos antes de reintentar
- **proxy_next_upstream_tries**: 3 intentos en diferentes servidores
- **proxy_next_upstream_timeout**: 10 segundos máximo por intento

### **Headers de Debug**
- `X-Upstream-Server`: Muestra qué instancia procesó la request
- `X-Response-Time`: Tiempo de respuesta del upstream

## 🧪 Escenarios de Prueba

### **1. Distribución Normal**
```powershell
# El tráfico se distribuye equitativamente entre las 3 instancias
.\scripts\test_load_balancer.ps1 -Requests 30
```

### **2. Simulación de Fallo**
```powershell
# Detiene una instancia y verifica failover automático
.\scripts\test_load_balancer.ps1 -TestFailover
```

### **3. Recuperación Automática**
```powershell
# Reinicia instancia caída y verifica reintegración
docker start eda-backend-app1
# El balanceador automáticamente incluye la instancia recuperada
```

## 📊 Métricas y Estadísticas

El script de prueba proporciona:
- **Distribución por servidor**: Porcentaje de requests por instancia
- **Tasa de éxito**: Requests exitosos vs fallidos
- **Tiempo de respuesta**: Latencia promedio
- **Estado de contenedores**: Status de cada instancia

## 🔧 Troubleshooting

### **Problema: Una instancia no responde**
```powershell
# Verificar logs de la instancia
docker logs eda-backend-app1

# Reiniciar instancia específica
docker restart eda-backend-app1
```

### **Problema: NGINX no balancea correctamente**
```powershell
# Verificar configuración de NGINX
docker exec nginx-load-balancer nginx -t

# Recargar configuración
docker exec nginx-load-balancer nginx -s reload
```

### **Problema: Health checks fallan**
```powershell
# Verificar endpoint de health directamente
curl http://localhost:8081/api/health
curl http://localhost:8082/api/health
curl http://localhost:8083/api/health
```

## 🚀 Próximos Pasos

### **Mejoras Planificadas**
1. **Sticky Sessions**: Para aplicaciones que requieren afinidad de sesión
2. **Rate Limiting**: Protección contra ataques DDoS
3. **SSL/TLS**: Terminación SSL en el balanceador
4. **Métricas Avanzadas**: Integración con Prometheus/Grafana
5. **Auto-scaling**: Escalado automático basado en carga

### **Configuraciones Adicionales**
- **Circuit Breaker**: Protección contra cascading failures
- **Retry Logic**: Reintentos inteligentes con backoff
- **Geographic Load Balancing**: Distribución por ubicación geográfica

## 📝 Notas Importantes

- ✅ **Compatibilidad**: El puerto 8080 se mantiene para compatibilidad con configuraciones existentes
- ✅ **Persistencia**: Todas las instancias comparten la misma base de datos PostgreSQL
- ✅ **Kafka**: Las 3 instancias se conectan al mismo cluster de Kafka
- ✅ **Logs**: Cada instancia mantiene logs independientes para debugging
- ✅ **Environment**: Cada instancia tiene un `INSTANCE_ID` único para identificación

### Persistencia de NGINX (DNS dinámico)
Desde ahora la configuración de NGINX incluye resolución dinámica de DNS para los upstreams dentro de Docker. Esto evita tener que reiniciar NGINX cuando se recrean `app1/app2/app3`:

```nginx
http {
  resolver 127.0.0.11 ipv6=off valid=30s;
  resolver_timeout 5s;

  upstream eda_backend {
    least_conn;
    server app1:8080 resolve max_fails=3 fail_timeout=30s weight=1;
    server app2:8080 resolve max_fails=3 fail_timeout=30s weight=1;
    server app3:8080 resolve max_fails=3 fail_timeout=30s weight=1;
  }
}

---

Navegación rápida: [Volver al README](../README.md) · [Índice de docs](index.md) · [Mapa del proyecto](project-map.md) · [Guía de entrevista](guia-entrevista-backend.md) · [Observabilidad](observability-overview.md)
```

Además, el endpoint `/api/health` añade el header `X-Upstream-Server` para diagnosticar qué instancia respondió.

## Interpretación rápida de HAProxy (PostgreSQL)

Esta guía complementa la sección de resiliencia de base de datos y explica cómo leer la página de estadísticas de HAProxy cuando se usa Patroni para gestionar roles de Postgres.

### Puertos y reglas por listener
- `master (5000)`: solo el líder debe aparecer `UP`. Réplicas aparecerán `DOWN` aquí por no cumplir el rol de escritura.
- `replicas (5001)`: solo réplicas deben aparecer `UP`. El líder aparecerá `DOWN` aquí por no cumplir el rol de lectura.
- `postgres-cluster (5002)`: los tres nodos deben estar `UP` si el API de Patroni responde al check `/health`; indica salud general del clúster.

### Cómo leer columnas clave
- `Status`: estado del servidor para ese backend. `UP` significa que cumple el rol del listener; `DOWN` suele significar “rol no apto para este listener”, no un fallo del nodo.
- `LastChk`: busca `L7STS/200` (check HTTP pasó) o `L7STS/503` (check no cumplido). `503` en `master` para una réplica es esperado; en `postgres-cluster` ahora debe ser `200` en todos si `/health` responde.
- `Act/Bck`: distingue servidores activos vs. de respaldo según la config. Útil para ver si algún nodo está marcado como backup.

### Consejos de visualización
- Usa “Hide DOWN servers” en la página de stats para ver solo los que aplican al listener.
- Para salud global, revisa `postgres-cluster :5002` y confirma `UP` en los tres nodos.

### Verificación rápida con `psql`
- Escritura (líder): `psql -h localhost -p 5000 -U <usuario> -d <db> -c "create table if not exists lb_probe(x int);"`
- Lectura (réplica): `psql -h localhost -p 5001 -U <usuario> -d <db> -c "select now();"`

Más detalles: consulta `docs/database-resilience.md`.

## 🎯 Beneficios Implementados

1. **Alta Disponibilidad**: Si una instancia falla, las otras continúan funcionando
2. **Escalabilidad**: Fácil agregar más instancias modificando docker-compose.yml
3. **Performance**: Distribución de carga mejora el rendimiento general
4. **Monitoreo**: Visibilidad completa del estado del sistema
5. **Automatización**: Failover y recovery completamente automáticos