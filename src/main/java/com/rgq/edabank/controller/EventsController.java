package com.rgq.edabank.controller;

import com.rgq.edabank.repository.PaymentRepository;
import com.rgq.edabank.repository.TransferRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/events")
public class EventsController {

    private static final Logger log = LoggerFactory.getLogger(EventsController.class);

    private final KafkaTemplate<String, String> kafkaTemplate;
    private final PaymentRepository paymentRepo;
    private final TransferRepository transferRepo;
    private final com.rgq.edabank.repository.OutboxRepository outboxRepo;

    public EventsController(KafkaTemplate<String, String> kafkaTemplate, PaymentRepository paymentRepo, TransferRepository transferRepo, com.rgq.edabank.repository.OutboxRepository outboxRepo) {
        this.kafkaTemplate = kafkaTemplate;
        this.paymentRepo = paymentRepo;
        this.transferRepo = transferRepo;
        this.outboxRepo = outboxRepo;
    }

    @PostMapping("/payments")
    public ResponseEntity<?> publishPayment(@jakarta.validation.Valid @org.springframework.web.bind.annotation.RequestBody com.rgq.edabank.dto.PaymentDto dto) {
        String key = UUID.randomUUID().toString();
        try {
            log.info("POST /events/payments received DTO: {}", dto);
            com.rgq.edabank.model.Payment p = new com.rgq.edabank.model.Payment();
            p.setId(dto.getId());
            p.setType(dto.getType() != null ? dto.getType() : "payment");
            p.setAmount(dto.getAmount());
            p.setCurrency(dto.getCurrency());
            p.setAccountId(dto.getAccountId());
            p.setPayload(new com.fasterxml.jackson.databind.ObjectMapper().writeValueAsString(dto));
            log.debug("Payment model prepared: id={}, accountId={}, payload={}", p.getId(), p.getAccountId(), p.getPayload());
            paymentRepo.insertPayment(p);
            // insert into outbox for durable publish
            com.rgq.edabank.model.Outbox o = new com.rgq.edabank.model.Outbox();
            o.setAggregateType("payment"); o.setAggregateId(p.getId()); o.setType("payments.events"); o.setPayload(p.getPayload());
            outboxRepo.insert(o);
        } catch (Exception e) {
            log.error("Failed to persist or publish payment DTO: {} , error: ", dto, e);
            return ResponseEntity.status(500).body("failed to persist or publish: " + e.getMessage());
        }
        return ResponseEntity.ok().body("published: payments.events key=" + key);
    }

    @PostMapping("/transfers")
    public ResponseEntity<?> publishTransfer(@jakarta.validation.Valid @org.springframework.web.bind.annotation.RequestBody com.rgq.edabank.dto.TransferDto dto) {
        String key = UUID.randomUUID().toString();
        try {
            log.info("POST /events/transfers received DTO: {}", dto);
            com.rgq.edabank.model.Transfer t = new com.rgq.edabank.model.Transfer();
            t.setId(dto.getId());
            t.setType(dto.getType() != null ? dto.getType() : "transfer");
            t.setAmount(dto.getAmount());
            t.setFromAccount(dto.getFrom());
            t.setToAccount(dto.getTo());
            t.setPayload(new com.fasterxml.jackson.databind.ObjectMapper().writeValueAsString(dto));
            log.debug("Transfer model prepared: id={}, from={}, to={}, payload={}", t.getId(), t.getFromAccount(), t.getToAccount(), t.getPayload());
            transferRepo.insertTransfer(t);
            com.rgq.edabank.model.Outbox o = new com.rgq.edabank.model.Outbox();
            o.setAggregateType("transfer"); o.setAggregateId(t.getId()); o.setType("transfers.events"); o.setPayload(t.getPayload());
            outboxRepo.insert(o);
        } catch (Exception e) {
            log.error("Failed to persist or publish transfer DTO: {} , error: ", dto, e);
            return ResponseEntity.status(500).body("failed to persist or publish: " + e.getMessage());
        }
        return ResponseEntity.ok().body("published: transfers.events key=" + key);
    }
}