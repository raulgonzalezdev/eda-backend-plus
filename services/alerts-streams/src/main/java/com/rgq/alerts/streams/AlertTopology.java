package com.rgq.alerts.streams;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.common.serialization.Serde;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.GlobalKTable;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.Produced;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AlertTopology {
    private static final Logger log = LoggerFactory.getLogger(AlertTopology.class);
    private final ObjectMapper mapper = new ObjectMapper();

    @Value("${app.alerts.threshold:10000}")
    private double threshold;

    @Value("${app.kafka.topics.payments:payments.events}")
    private String paymentsTopic;

    @Value("${app.kafka.topics.transfers:transfers.events}")
    private String transfersTopic;

    @Value("${app.kafka.topics.alerts:alerts.suspect}")
    private String alertsTopic;

    @Value("${app.kafka.topics.rules:alerts.rules}")
    private String rulesTopic;

    @Bean
    public KStream<String, String> kstream(StreamsBuilder streamsBuilder) {
        Serde<String> stringSerde = Serdes.String();

        KStream<String, String> payments = streamsBuilder.stream(paymentsTopic, Consumed.with(stringSerde, stringSerde));
        KStream<String, String> transfers = streamsBuilder.stream(transfersTopic, Consumed.with(stringSerde, stringSerde));
        KStream<String, String> merged = payments.merge(transfers).peek((k, v) -> log.debug("evt key={} payload={}", k, v));

        // Reglas dinámicas como GlobalKTable (clave: type o tenantId:type, valor: JSON con threshold)
        GlobalKTable<String, String> rulesTable = streamsBuilder.globalTable(rulesTopic, Consumed.with(stringSerde, stringSerde));

        // Proyectar clave del stream a 'type' o 'tenantId:type' para el join con reglas
        KStream<String, String> withTypeKey = merged.selectKey((k, v) -> {
            try {
                JsonNode node = mapper.readTree(v);
                String type = node.has("type") ? node.get("type").asText("unknown") : "unknown";
                String tenantId = node.has("tenantId") ? node.get("tenantId").asText("") : "";
                return (tenantId != null && !tenantId.isBlank()) ? tenantId + ":" + type : type;
            } catch (Exception e) {
                return "unknown";
            }
        });

        // Join con reglas: si existe regla para 'type', aplicar su 'threshold'; si no, usar default
        KStream<String, String> alerts = withTypeKey.join(
            rulesTable,
            (evtKey, evtVal) -> evtKey, // clave de búsqueda en reglas
            (evtVal, ruleJson) -> {
                try {
                    double effectiveThreshold = threshold;
                    if (ruleJson != null) {
                        JsonNode r = mapper.readTree(ruleJson);
                        if (r.has("threshold")) {
                            effectiveThreshold = r.get("threshold").asDouble(threshold);
                        }
                        if (r.has("enabled") && !r.get("enabled").asBoolean(true)) {
                            return null; // regla deshabilitada
                        }
                    }
                    JsonNode node = mapper.readTree(evtVal);
                    double amount = node.has("amount") ? node.get("amount").asDouble(0.0) : 0.0;
                    String type = node.has("type") ? node.get("type").asText("unknown") : "unknown";
                    String tenantId = node.has("tenantId") ? node.get("tenantId").asText(null) : null;
                    if (amount >= effectiveThreshold) {
                        String tField = (tenantId != null) ? ",\"tenantId\":\"" + tenantId + "\"" : "";
                        return "{\"alert\":\"threshold_exceeded\",\"type\":\"" + type + "\"" + tField + ",\"amount\":" + amount + "}";
                    }
                } catch (Exception e) {
                    log.warn("Error evaluando regla/payload: {}", e.getMessage());
                }
                return null;
            }
        ).filter((k, v) -> v != null);

        alerts.to(alertsTopic, Produced.with(stringSerde, stringSerde));
        return merged;
    }
}