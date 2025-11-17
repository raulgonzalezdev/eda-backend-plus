package com.rgq.alerts.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.rgq.alerts.config.dto.RuleDto;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/rules")
public class RulesController {
    private static final Logger log = LoggerFactory.getLogger(RulesController.class);

    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper mapper = new ObjectMapper();

    @Value("${app.kafka.topics.rules:alerts.rules}")
    private String rulesTopic;

    public RulesController(KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    @PostMapping
    public ResponseEntity<?> upsertRule(@RequestBody RuleDto rule) {
        try {
            if (rule.getType() == null || rule.getType().isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("error","type is required"));
            }
            Double threshold = rule.getThreshold() != null ? rule.getThreshold() : 0.0;
            Boolean enabled = rule.getEnabled() != null ? rule.getEnabled() : true;
            String payload = mapper.writeValueAsString(Map.of(
                    "type", rule.getType(),
                    "threshold", threshold,
                    "enabled", enabled
            ));
            kafkaTemplate.send(rulesTopic, rule.getType(), payload).get();
            log.info("Rule upserted: key={} payload={} topic={}", rule.getType(), payload, rulesTopic);
            return ResponseEntity.ok(Map.of("status","ok"));
        } catch (Exception e) {
            log.error("Error producing rule: {}", e.getMessage());
            return ResponseEntity.internalServerError().body(Map.of("error","failed to upsert rule"));
        }
    }

    @GetMapping("/health")
    public Map<String, String> health() { return Map.of("status","UP"); }
}