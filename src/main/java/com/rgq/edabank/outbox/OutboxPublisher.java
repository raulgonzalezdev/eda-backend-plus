package com.rgq.edabank.outbox;

import com.rgq.edabank.model.Outbox;
import com.rgq.edabank.repository.OutboxRepository;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.data.domain.PageRequest;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class OutboxPublisher {

    private final OutboxRepository outboxRepo;
    private final KafkaTemplate<String, String> kafka;
    private final MeterRegistry meter;

    public OutboxPublisher(OutboxRepository outboxRepo, KafkaTemplate<String, String> kafka, MeterRegistry meter) {
        this.outboxRepo = outboxRepo;
        this.kafka = kafka;
        this.meter = meter;
    }

    @Scheduled(fixedDelayString = "${outbox.poll.ms:5000}")
    public void poll() {
        List<Outbox> list = outboxRepo.findBySentFalseOrderByCreatedAtAsc(PageRequest.of(0, 50));
        for (Outbox o : list) {
            try {
                kafka.send(o.getType(), o.getAggregateId(), o.getPayload()).get();
                outboxRepo.markSent(o.getId());
                meter.counter("outbox.published.success").increment();
            } catch (Exception e) {
                meter.counter("outbox.published.failure").increment();
            }
        }
    }
}
