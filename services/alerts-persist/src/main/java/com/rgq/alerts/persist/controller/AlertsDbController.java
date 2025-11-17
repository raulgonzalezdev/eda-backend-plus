package com.rgq.alerts.persist.controller;

import com.rgq.alerts.persist.repository.AlertsRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/alerts-db")
public class AlertsDbController {

    private final AlertsRepository alertsRepo;

    public AlertsDbController(AlertsRepository alertsRepo) {
        this.alertsRepo = alertsRepo;
    }

    @GetMapping
    public ResponseEntity<?> list(@RequestParam(name = "tenantId", required = false) String tenantId) {
        if (tenantId != null && !tenantId.isBlank()) {
            return ResponseEntity.ok(alertsRepo.findTop100ByTenantIdOrderByCreatedAtDesc(tenantId));
        }
        return ResponseEntity.ok(alertsRepo.findTop100ByOrderByCreatedAtDesc());
    }
}