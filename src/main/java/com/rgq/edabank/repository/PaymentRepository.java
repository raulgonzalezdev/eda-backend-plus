package com.rgq.edabank.repository;

import com.rgq.edabank.model.Payment;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class PaymentRepository {
    private static final Logger log = LoggerFactory.getLogger(PaymentRepository.class);
    private final JdbcTemplate jdbc;

    public PaymentRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insertPayment(Payment p) {
        try {
            log.debug("Inserting payment id={}, accountId={}, payload={}", p.getId(), p.getAccountId(), p.getPayload());
            jdbc.update("INSERT INTO pos.payments (id,type,amount,currency,account_id,payload) VALUES (?,?,?,?,?,CAST(? AS jsonb))",
                    p.getId(), p.getType(), p.getAmount(), p.getCurrency(), p.getAccountId(), p.getPayload());
        } catch (Exception e) {
            io.micrometer.core.instrument.Metrics.counter("persist.failures", "entity", "payment").increment();
            log.error("insertPayment failed for id={}, error:", p.getId(), e);
            throw e;
        }
    }
}