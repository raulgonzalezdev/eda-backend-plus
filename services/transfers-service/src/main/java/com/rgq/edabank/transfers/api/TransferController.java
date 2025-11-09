package com.rgq.edabank.transfers.api;

import lombok.RequiredArgsConstructor;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequiredArgsConstructor
public class TransferController {
    private final KafkaTemplate<String, Object> kafkaTemplate;

    @PostMapping("/transfers")
    public ResponseEntity<?> createTransfer(@RequestBody Map<String, Object> payload) {
        String key = (String) payload.getOrDefault("id", null);
        ProducerRecord<String, Object> record = new ProducerRecord<>("transfers.events", key, payload);
        kafkaTemplate.send(record);
        return ResponseEntity.accepted().build();
    }
}