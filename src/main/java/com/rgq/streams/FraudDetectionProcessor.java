package com.rgq.streams;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jayway.jsonpath.JsonPath;
import com.rgq.events.PaymentEvent;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.KStream;
import org.kie.api.runtime.KieContainer;
import org.kie.api.runtime.KieSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class FraudDetectionProcessor {

    private static final String INPUT_TOPIC = "dbz-outbox.pos.outbox";
    private static final String OUTPUT_TOPIC = "alerts.suspect";

    @Autowired
    private KieContainer kieContainer;

    @Autowired
    private KafkaTemplate<String, String> kafkaTemplate;

    private ObjectMapper objectMapper = new ObjectMapper();

    @Autowired
    void buildPipeline(StreamsBuilder streamsBuilder) {
        KStream<String, String> messageStream = streamsBuilder
                .stream(INPUT_TOPIC, Consumed.with(Serdes.String(), Serdes.String()));

        messageStream.foreach((key, value) -> {
            try {
                String payload = JsonPath.read(value, "$.payload.after.payload");
                PaymentEvent paymentEvent = objectMapper.readValue(payload, PaymentEvent.class);

                KieSession kieSession = kieContainer.newKieSession();
                kieSession.setGlobal("kafkaTemplate", kafkaTemplate);
                kieSession.insert(paymentEvent);
                kieSession.fireAllRules();
                kieSession.dispose();
            } catch (Exception e) {
                // Manejar la excepción
            }
        });
    }
}