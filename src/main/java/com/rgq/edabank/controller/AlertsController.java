package com.rgq.edabank.controller;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.util.*;

@RestController
@RequestMapping("/alerts")
public class AlertsController {

    @Value("${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}")
    private String bootstrapServers;

    @GetMapping
    public ResponseEntity<?> getAlerts(@RequestParam(name = "timeoutMs", defaultValue = "2000") long timeoutMs) {
        Properties props = new Properties();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.GROUP_ID_CONFIG, "alerts-consumer-" + UUID.randomUUID());
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");

        List<Map<String, Object>> results = new ArrayList<>();
        try (KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props)) {
            consumer.subscribe(Collections.singletonList("alerts.suspect"));
            ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(timeoutMs));
            for (ConsumerRecord<String, String> r : records) {
                Map<String, Object> m = new HashMap<>();
                m.put("key", r.key());
                m.put("value", r.value());
                m.put("partition", r.partition());
                m.put("offset", r.offset());
                m.put("timestamp", r.timestamp());
                results.add(m);
            }
        } catch (Exception e) {
            return ResponseEntity.status(500).body("failed to consume alerts: " + e.getMessage());
        }

        return ResponseEntity.ok(results);
    }
}
