package com.rgq.alerts.persist.consumer;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.rgq.alerts.persist.model.Alert;
import com.rgq.alerts.persist.repository.AlertsRepository;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Component
public class AlertsConsumer {

    private static final Logger log = LoggerFactory.getLogger(AlertsConsumer.class);
    private final AlertsRepository alertsRepo;
    private final ObjectMapper mapper = new ObjectMapper();

    public AlertsConsumer(AlertsRepository alertsRepo) {
        this.alertsRepo = alertsRepo;
    }

    @Value("${app.kafka.topics.alerts:alerts.suspect}")
    private String alertsTopic;

    @KafkaListener(topics = "${app.kafka.topics.alerts:alerts.suspect}", groupId = "alerts-persist-group", containerFactory = "stringKafkaListenerContainerFactory")
    public void onMessage(ConsumerRecord<String, String> record) {
        try {
            String payload = record.value();
            if (payload == null || payload.isEmpty()) {
                log.warn("Payload vacío; mensaje ignorado");
                return;
            }
            JsonNode node = mapper.readTree(payload);
            String type = node.has("type") ? node.get("type").asText("unknown") : "unknown";
            double amount = node.has("amount") ? node.get("amount").asDouble(0.0) : 0.0;

            Alert a = new Alert();
            a.setEventId(null);
            a.setAlertType("threshold_exceeded");
            a.setSourceType(type);
            a.setAmount(amount);
            a.setPayload(payload);
            a.setKafkaPartition(record.partition());
            a.setKafkaOffset(record.offset());

            alertsRepo.save(a);
            log.info("Persistida alerta: partition={} offset={} type={} amount={}", record.partition(), record.offset(), type, amount);
        } catch (Exception e) {
            log.error("Error procesando alerta: {}", e.getMessage(), e);
        }
    }
}