package com.rgq.edabank.outbox;

import com.rgq.edabank.model.Outbox;
import com.rgq.edabank.repository.OutboxRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Component
public class OutboxPublisher {
    private static final Logger LOG = LoggerFactory.getLogger(OutboxPublisher.class);
    private final OutboxRepository outboxRepo;
    private final KafkaTemplate<String, String> kafka;
    private final MeterRegistry meter;

    public OutboxPublisher(OutboxRepository outboxRepo, KafkaTemplate<String, String> kafka, MeterRegistry meter) {
        this.outboxRepo = outboxRepo;
        this.kafka = kafka;
        this.meter = meter;
    }

    @Scheduled(fixedRate = 10000)
    public void publishEvents() {
        Pageable pageable = PageRequest.of(0, 100);
        List<Outbox> events = outboxRepo.findBySentFalseOrderByCreatedAtAsc(pageable);
        for (Outbox event : events) {
            LOG.info("Publishing event: {}", event);
            try {
                kafka.send(event.getType(), event.getAggregateId(), event.getPayload()).get();
                event.setSent(true);
                outboxRepo.save(event);
            } catch (Exception e) {
                LOG.error("Error publishing event: {}", event, e);
            }
        }
    }
}
