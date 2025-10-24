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
    KStream<String, String> payments = streamsBuilder.stream("payments.events", Consumed.with(stringSerde, stringSerde));
    KStream<String, String> transfers = streamsBuilder.stream("transfers.events", Consumed.with(stringSerde, stringSerde));

    KStream<String, String> merged = payments.merge(transfers).peek((k, v) -> log.debug("evt key={} payload={}", k, v));

    KStream<String, String> alerts = merged.filter((k, v) -> {
      try {
        JsonNode node = mapper.readTree(v);
        double amount = node.has("amount") ? node.get("amount").asDouble(0.0) : 0.0;
        return amount >= threshold;
      } catch (Exception e) {
        log.warn("Invalid JSON payload: {}", v);
        return false;
      }
    }).mapValues(v -> {
      try {
        JsonNode node = mapper.readTree(v);
        String type = node.has("type") ? node.get("type").asText("unknown") : "unknown";
        double amount = node.has("amount") ? node.get("amount").asDouble(0.0) : 0.0;
        String id = node.has("id") ? node.get("id").asText("") : "";
        return "{\"alert\":\"threshold_exceeded\",\"type\":\"" + type + "\",\"amount\":" + amount + ",\"id\":\"" + id + "\"}";
      } catch (Exception e) {
        return "{\"alert\":\"parse_error\"}";
      }
    });

    alerts.to("alerts.suspect", Produced.with(stringSerde, stringSerde));
    return merged;
  }

  @Bean
  public StreamsBuilder streamsBuilder() {
    return new StreamsBuilder();
  }
}
