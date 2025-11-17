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

    @Value("${app.security.rulesApiKey:}")
    private String rulesApiKey;

    @Value("${app.security.enforceTenantHeader:false}")
    private boolean enforceTenantHeader;

    public RulesController(KafkaTemplate<String, String> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    @PostMapping
    public ResponseEntity<?> upsertRule(@RequestBody RuleDto rule,
                                        @RequestHeader(value = "X-API-Key", required = false) String apiKey,
                                        @RequestHeader(value = "X-Tenant-Id", required = false) String tenantHeader) {
        try {
            if (rulesApiKey != null && !rulesApiKey.isBlank()) {
                if (apiKey == null || !apiKey.equals(rulesApiKey)) {
                    return ResponseEntity.status(401).body(Map.of("error","invalid api key"));
                }
            }
            if (rule.getType() == null || rule.getType().isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("error","type is required"));
            }
            if (enforceTenantHeader) {
                String fromHeader = (tenantHeader != null && !tenantHeader.isBlank()) ? tenantHeader : null;
                String fromBody = (rule.getTenantId() != null && !rule.getTenantId().isBlank()) ? rule.getTenantId() : null;
                if (fromHeader == null || fromBody == null || !fromHeader.equals(fromBody)) {
                    return ResponseEntity.status(403).body(Map.of("error","tenant header/body mismatch"));
                }
            }
            Double threshold = rule.getThreshold() != null ? rule.getThreshold() : 0.0;
            Boolean enabled = rule.getEnabled() != null ? rule.getEnabled() : true;
            String key = (rule.getTenantId() != null && !rule.getTenantId().isBlank())
                    ? rule.getTenantId() + ":" + rule.getType()
                    : rule.getType();

            String payload = mapper.writeValueAsString(Map.of(
                    "type", rule.getType(),
                    "tenantId", rule.getTenantId(),
                    "threshold", threshold,
                    "enabled", enabled
            ));
            kafkaTemplate.send(rulesTopic, key, payload).get();
            log.info("Rule upserted: key={} payload={} topic={}", key, payload, rulesTopic);
            return ResponseEntity.ok(Map.of("status","ok"));
        } catch (Exception e) {
            log.error("Error producing rule: {}", e.getMessage());
            return ResponseEntity.internalServerError().body(Map.of("error","failed to upsert rule"));
        }
    }

    @GetMapping("/health")
    public Map<String, String> health() { return Map.of("status","UP"); }
}