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

    @KafkaListener(topics = "alerts.suspect", groupId = "alerts-persist-group", containerFactory = "stringKafkaListenerContainerFactory")
    public void onMessage(ConsumerRecord<String, String> record) {
        try {
            System.out.println("=== RECIBIENDO MENSAJE DE KAFKA ====");
            String payload = record.value();
            System.out.println("Payload recibido: " + payload);
            
            if (payload == null || payload.isEmpty()) {
                System.err.println("ALERTA CRÍTICA: El payload recibido es nulo o vacío");
                return; // No procesamos mensajes vacíos
            }
            
            System.out.println("Parseando JSON del payload...");
            JsonNode node = mapper.readTree(payload);
            String type = node.has("type") ? node.get("type").asText("unknown") : "unknown";
            double amount = node.has("amount") ? node.get("amount").asDouble(0.0) : 0.0;
            String tenantId = (node.has("tenantId") && !node.get("tenantId").isNull()) ? node.get("tenantId").asText() : null;
            
            System.out.println("Valores extraídos: type=" + type + ", amount=" + amount);
            
            com.rgq.edabank.model.Alert a = new com.rgq.edabank.model.Alert();
            a.setEventId(null);
            a.setAlertType("threshold_exceeded");
            a.setSourceType(type);
            a.setAmount(amount);
            a.setTenantId(tenantId);
            a.setPayload(payload);
            a.setKafkaPartition(record.partition());
            a.setKafkaOffset(record.offset());
            
            System.out.println("Objeto Alert creado con payload: " + a.getPayload());
            System.out.println("Enviando a repositorio para inserción...");
            
            alertsRepo.save(a);
            System.out.println("=== PROCESAMIENTO DE MENSAJE COMPLETADO ====");
        } catch (Exception e) {
            // log detallado del error
            System.err.println("=== ERROR AL PROCESAR MENSAJE ====");
            System.err.println("Failed to persist alert: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
