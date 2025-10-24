package com.rgq.edabank.controller;

import com.rgq.edabank.repository.AlertsRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/alerts-db")
public class AlertsDbController {

    private final AlertsRepository alertsRepo;

    public AlertsDbController(AlertsRepository alertsRepo) {
        this.alertsRepo = alertsRepo;
    }

    @GetMapping
    public ResponseEntity<?> list() {
        return ResponseEntity.ok(alertsRepo.findAll());
    }
}
