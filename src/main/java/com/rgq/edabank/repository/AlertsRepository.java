package com.rgq.edabank.repository;

import com.rgq.edabank.model.Alert;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;

@Repository
public class AlertsRepository {
    private final JdbcTemplate jdbc;

    public AlertsRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insertAlert(Alert a) {
        try {
            jdbc.update("INSERT INTO alerts (event_id, alert_type, source_type, amount, payload, kafka_partition, kafka_offset) VALUES (?,?,?,?,?::jsonb,?,?)",
                    a.getEventId(), a.getAlertType(), a.getSourceType(), a.getAmount(), a.getPayload(), a.getKafkaPartition(), a.getKafkaOffset());
        } catch (Exception e) {
            io.micrometer.core.instrument.Metrics.counter("persist.failures", "entity", "alert").increment();
            throw e;
        }
    }

    private final RowMapper<Alert> mapper = new RowMapper<>() {
        @Override
        public Alert mapRow(ResultSet rs, int rowNum) throws SQLException {
            Alert a = new Alert();
            a.setId(rs.getLong("id"));
            a.setEventId(rs.getString("event_id"));
            a.setAlertType(rs.getString("alert_type"));
            a.setSourceType(rs.getString("source_type"));
            a.setAmount(rs.getDouble("amount"));
            a.setPayload(rs.getString("payload"));
            a.setCreatedAt(rs.getObject("created_at", OffsetDateTime.class));
            return a;
        }
    };

    public List<Alert> findAll() {
        return jdbc.query("SELECT id,event_id,alert_type,source_type,amount,payload,created_at FROM alerts ORDER BY created_at DESC LIMIT 100", mapper);
    }
}