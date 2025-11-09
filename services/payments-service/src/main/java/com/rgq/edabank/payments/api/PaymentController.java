package com.rgq.edabank.payments.api;

import lombok.RequiredArgsConstructor;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequiredArgsConstructor
public class PaymentController {
    private final KafkaTemplate<String, Object> kafkaTemplate;

    @PostMapping("/payments")
    public ResponseEntity<?> createPayment(@RequestBody Map<String, Object> payload) {
        String key = (String) payload.getOrDefault("id", null);
        ProducerRecord<String, Object> record = new ProducerRecord<>("payments.events", key, payload);
        kafkaTemplate.send(record);
        return ResponseEntity.accepted().build();
    }
}