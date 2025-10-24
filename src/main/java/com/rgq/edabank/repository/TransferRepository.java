package com.rgq.edabank.repository;

import com.rgq.edabank.model.Transfer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class TransferRepository {
    private static final Logger log = LoggerFactory.getLogger(TransferRepository.class);
    private final JdbcTemplate jdbc;

    public TransferRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insertTransfer(Transfer t) {
        try {
            log.debug("Inserting transfer id={}, from={}, to={}, payload={}", t.getId(), t.getFromAccount(), t.getToAccount(), t.getPayload());
            jdbc.update("INSERT INTO transfers (id,type,amount,from_account,to_account,payload) VALUES (?,?,?,?,?,CAST(? AS jsonb))",
                    t.getId(), t.getType(), t.getAmount(), t.getFromAccount(), t.getToAccount(), t.getPayload());
        } catch (Exception e) {
            io.micrometer.core.instrument.Metrics.counter("persist.failures", "entity", "transfer").increment();
            log.error("insertTransfer failed for id={}, error:", t.getId(), e);
            throw e;
        }
    }
}