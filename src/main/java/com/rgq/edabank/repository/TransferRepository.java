package com.rgq.edabank.repository;

import com.rgq.edabank.model.Transfer;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class TransferRepository {
    private final JdbcTemplate jdbc;

    public TransferRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insertTransfer(Transfer t) {
        try {
            jdbc.update("INSERT INTO transfers (id,type,amount,from_account,to_account,payload) VALUES (?,?,?,?,?,?::jsonb)",
                    t.getId(), t.getType(), t.getAmount(), t.getFromAccount(), t.getToAccount(), t.getPayload());
        } catch (Exception e) {
            io.micrometer.core.instrument.Metrics.counter("persist.failures", "entity", "transfer").increment();
            throw e;
        }
    }
}