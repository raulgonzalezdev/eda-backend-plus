package com.rgq.edabank.streams;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.rgq.edabank.repository.AlertsRepository;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Component
public class AlertsConsumer {

    private final AlertsRepository alertsRepo;
    private final ObjectMapper mapper = new ObjectMapper();

    public AlertsConsumer(AlertsRepository alertsRepo) {
        this.alertsRepo = alertsRepo;
    }

    @KafkaListener(topics = "alerts.suspect", groupId = "alerts-persist-group")
    public void onMessage(ConsumerRecord<String, String> record) {
        try {
            String payload = record.value();
            JsonNode node = mapper.readTree(payload);
            String type = node.has("type") ? node.get("type").asText("unknown") : "unknown";
            double amount = node.has("amount") ? node.get("amount").asDouble(0.0) : 0.0;
            com.rgq.edabank.model.Alert a = new com.rgq.edabank.model.Alert();
            a.setEventId(null);
            a.setAlertType("threshold_exceeded");
            a.setSourceType(type);
            a.setAmount(amount);
            a.setPayload(payload);
            a.setKafkaPartition(record.partition());
            a.setKafkaOffset(record.offset());
            alertsRepo.insertAlert(a);
        } catch (Exception e) {
            // log and ignore
            System.err.println("Failed to persist alert: " + e.getMessage());
        }
    }
}
