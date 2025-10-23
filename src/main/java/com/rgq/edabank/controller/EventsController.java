package com.rgq.edabank.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/events")
public class EventsController {

    private final KafkaTemplate<String, String> kafkaTemplate;

    public EventsController(KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    @PostMapping("/payments")
    public ResponseEntity<?> publishPayment(@RequestBody String payload) {
        String key = UUID.randomUUID().toString();
        kafkaTemplate.send("payments.events", key, payload);
        return ResponseEntity.ok().body("published: payments.events key=" + key);
    }

    @PostMapping("/transfers")
    public ResponseEntity<?> publishTransfer(@RequestBody String payload) {
        String key = UUID.randomUUID().toString();
        kafkaTemplate.send("transfers.events", key, payload);
        return ResponseEntity.ok().body("published: transfers.events key=" + key);
    }
}
