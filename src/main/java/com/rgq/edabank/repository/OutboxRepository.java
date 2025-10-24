package com.rgq.edabank.repository;

import com.rgq.edabank.model.Outbox;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;

@Repository
public class OutboxRepository {
    private final JdbcTemplate jdbc;

    public OutboxRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insert(Outbox o) {
        jdbc.update("INSERT INTO pos.outbox (aggregate_type, aggregate_id, type, payload, sent) VALUES (?,?,?,?,false)",
                o.getAggregateType(), o.getAggregateId(), o.getType(), o.getPayload());
    }

    private final RowMapper<Outbox> mapper = new RowMapper<>() {
        @Override
        public Outbox mapRow(ResultSet rs, int rowNum) throws SQLException {
            Outbox o = new Outbox();
            o.setId(rs.getLong("id"));
            o.setAggregateType(rs.getString("aggregate_type"));
            o.setAggregateId(rs.getString("aggregate_id"));
            o.setType(rs.getString("type"));
            o.setPayload(rs.getString("payload"));
            o.setSent(rs.getBoolean("sent"));
            o.setCreatedAt(rs.getObject("created_at", OffsetDateTime.class));
            return o;
        }
    };

    public List<Outbox> fetchUnsent(int limit) {
        return jdbc.query("SELECT id,aggregate_type,aggregate_id,type,payload,sent,created_at FROM pos.outbox WHERE sent=false ORDER BY created_at ASC LIMIT ?", new Object[]{limit}, mapper);
    }

    public void markSent(Long id) {
        jdbc.update("UPDATE pos.outbox SET sent=true WHERE id=?", id);
    }
}
