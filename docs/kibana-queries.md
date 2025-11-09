# Kibana: Consultas y Guía Rápida

## Endpoints útiles
- Data Views: `http://localhost:5601/app/management/kibana/dataViews`
- Discover: `http://localhost:5601/app/discover`
- Lens: `http://localhost:5601/app/lens`

## Data View backend.events
- Pattern: `backend.events-*`
- Time field: `@timestamp`

## Consultas en Dev Tools

### Ver índices
```
GET _cat/indices?v
GET _cat/indices/backend.events-*?v
GET _cat/indices/alerts.enriched-*?v
```

### Últimos documentos backend.events
```
POST backend.events-*/_search
{
  "size": 10,
  "sort": [{ "@timestamp": "desc" }],
  "_source": ["@timestamp","endpoint","latency_ms","status_code","user_id","amount","pipeline"]
}
```

### Filtrar por pipeline
```
POST backend.events-*/_search
{
  "query": { "term": { "pipeline.keyword": "backend_events" } },
  "size": 10,
  "sort": [{ "@timestamp": "desc" }]
}
```

### Agregaciones
```
POST backend.events-*/_search
{
  "size": 0,
  "aggs": {
    "by_endpoint": { "terms": { "field": "endpoint.keyword" } },
    "latency_avg": { "avg": { "field": "latency_ms" } },
    "amount_avg": { "avg": { "field": "amount" } }
  }
}
```

## Gráficos (Lens)

### Eventos por minuto
- Métrica: `Count`
- Eje X: `@timestamp` (Date histogram, 1m)

### Latencia media por endpoint
- Métrica: `Average(latency_ms)`
- Segmentación: `endpoint.keyword`

### Monto promedio por endpoint
- Métrica: `Average(amount)`
- Segmentación: `endpoint.keyword`

## APM (Errores y métricas)

### Buscar SerializationException
```
POST logs-apm*/_search
{
  "size": 20,
  "sort": [{ "@timestamp": "desc" }],
  "query": { "match_phrase": { "error.exception.message": "SerializationException" } }
}
```

## Notas
- Ajusta el rango de tiempo en Kibana (arriba a la derecha) si no ves datos.
- En Discover, añade columnas: `@timestamp`, `endpoint`, `latency_ms`, `status_code`, `user_id`, `amount`, `pipeline`.