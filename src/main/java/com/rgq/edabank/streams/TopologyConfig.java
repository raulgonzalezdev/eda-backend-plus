package com.rgq.edabank.streams;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.common.serialization.Serde;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.Produced;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class TopologyConfig {
  private static final Logger log = LoggerFactory.getLogger(TopologyConfig.class);
  private final ObjectMapper mapper = new ObjectMapper();

  @Value("${app.alerts.threshold:10000}")
  private double threshold;

  @Bean
  public KStream<String, String> kstream(StreamsBuilder streamsBuilder) {
    Serde<String> stringSerde = Serdes.String();
    
    // Procesar eventos del outbox de Debezium
    KStream<String, String> outboxEvents = streamsBuilder.stream("dbz-outbox.pos.outbox", Consumed.with(stringSerde, stringSerde));
    
    KStream<String, String> processedEvents = outboxEvents.peek((k, v) -> log.debug("Debezium event key={} payload={}", k, v));

    KStream<String, String> alerts = processedEvents.filter((k, v) -> {
      try {
        // Parsear el evento de Debezium
        JsonNode debeziumEvent = mapper.readTree(v);
        
        // Extraer el payload del evento
        JsonNode payload = debeziumEvent.path("payload");
        if (payload.isMissingNode()) {
          log.warn("No payload found in Debezium event: {}", v);
          return false;
        }
        
        // Extraer el payload interno del outbox
        JsonNode after = payload.path("after");
        if (after.isMissingNode()) {
          log.warn("No 'after' field found in Debezium payload: {}", v);
          return false;
        }
        
        String outboxPayload = after.path("payload").asText("");
        if (outboxPayload.isEmpty()) {
          log.warn("Empty outbox payload in event: {}", v);
          return false;
        }
        
        // Parsear el payload del evento original
        JsonNode eventData = mapper.readTree(outboxPayload);
        double amount = eventData.path("amount").asDouble(0.0);
        
        log.info("Processing event with amount: {} (threshold: {})", amount, threshold);
        return amount >= threshold;
        
      } catch (Exception e) {
        log.warn("Error processing Debezium event: {} - {}", v, e.getMessage());
        return false;
      }
    }).mapValues(v -> {
      try {
        // Parsear el evento de Debezium
        JsonNode debeziumEvent = mapper.readTree(v);
        JsonNode after = debeziumEvent.path("payload").path("after");
        String outboxPayload = after.path("payload").asText("");
        
        // Parsear el payload del evento original
        JsonNode eventData = mapper.readTree(outboxPayload);
        String type = eventData.path("type").asText("unknown");
        double amount = eventData.path("amount").asDouble(0.0);
        String id = eventData.path("id").asText("");
        String aggregateId = after.path("aggregate_id").asText("");
        
        String alertPayload = "{\"alert\":\"threshold_exceeded\",\"type\":\"" + type + "\",\"amount\":" + amount + ",\"id\":\"" + id + "\",\"aggregate_id\":\"" + aggregateId + "\"}";
        log.info("Generated alert: {}", alertPayload);
        return alertPayload;
        
      } catch (Exception e) {
        log.error("Error generating alert from event: {} - {}", v, e.getMessage());
        return "{\"alert\":\"parse_error\",\"error\":\"" + e.getMessage() + "\"}";
      }
    });

    alerts.to("alerts.suspect", Produced.with(stringSerde, stringSerde));
    return processedEvents;
  }
}
