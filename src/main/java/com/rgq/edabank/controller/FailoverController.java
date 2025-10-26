package com.rgq.edabank.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/failover")
public class FailoverController {

    private static final Logger logger = LoggerFactory.getLogger(FailoverController.class);

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private DataSource dataSource;

    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getFailoverStatus() {
        Map<String, Object> status = new HashMap<>();
        
        try {
            // Verificar conexión actual
            String currentDb = jdbcTemplate.queryForObject(
                "SELECT current_database()", String.class);
            
            String serverInfo = jdbcTemplate.queryForObject(
                "SELECT version()", String.class);
            
            // Intentar determinar qué base de datos estamos usando
            String host = "unknown";
            try (Connection conn = dataSource.getConnection()) {
                String url = conn.getMetaData().getURL();
                if (url.contains("postgres-local") || url.contains("5433")) {
                    host = "postgres-local (primary)";
                } else if (url.contains("postgres-backup") || url.contains("5434")) {
                    host = "postgres-backup (backup)";
                }
            }
            
            status.put("status", "healthy");
            status.put("current_database", currentDb);
            status.put("current_host", host);
            status.put("server_info", serverInfo.substring(0, Math.min(50, serverInfo.length())) + "...");
            status.put("timestamp", System.currentTimeMillis());
            
            return ResponseEntity.ok(status);
            
        } catch (Exception e) {
            logger.error("Error checking failover status", e);
            status.put("status", "error");
            status.put("error", e.getMessage());
            status.put("timestamp", System.currentTimeMillis());
            
            return ResponseEntity.status(500).body(status);
        }
    }

    @PostMapping("/test-connection")
    public ResponseEntity<Map<String, Object>> testConnection() {
        Map<String, Object> result = new HashMap<>();
        
        try {
            // Probar conexión con una consulta simple
            Integer testResult = jdbcTemplate.queryForObject("SELECT 1", Integer.class);
            
            result.put("connection_test", "success");
            result.put("test_result", testResult);
            result.put("timestamp", System.currentTimeMillis());
            
            return ResponseEntity.ok(result);
            
        } catch (Exception e) {
            logger.error("Connection test failed", e);
            result.put("connection_test", "failed");
            result.put("error", e.getMessage());
            result.put("timestamp", System.currentTimeMillis());
            
            return ResponseEntity.status(500).body(result);
        }
    }

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> healthCheck() {
        Map<String, Object> health = new HashMap<>();
        
        try {
            // Health check básico
            jdbcTemplate.queryForObject("SELECT 1", Integer.class);
            
            health.put("database", "UP");
            health.put("failover_system", "ACTIVE");
            health.put("timestamp", System.currentTimeMillis());
            
            return ResponseEntity.ok(health);
            
        } catch (Exception e) {
            health.put("database", "DOWN");
            health.put("failover_system", "ERROR");
            health.put("error", e.getMessage());
            health.put("timestamp", System.currentTimeMillis());
            
            return ResponseEntity.status(503).body(health);
        }
    }
}