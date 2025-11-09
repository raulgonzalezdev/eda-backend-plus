package com.rgq.edabank.alerts.streams;

import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.Produced;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.Map;

@Configuration
public class AlertsTopology {
    @Bean
    public org.apache.kafka.streams.Topology topology() {
        StreamsBuilder builder = new StreamsBuilder();
        var payments = builder.stream("payments.events", Consumed.with(Serdes.String(), Serdes.serdeFrom(new org.springframework.kafka.support.serializer.JsonSerializer<>(), new org.springframework.kafka.support.serializer.JsonDeserializer<>())));
        var transfers = builder.stream("transfers.events", Consumed.with(Serdes.String(), Serdes.serdeFrom(new org.springframework.kafka.support.serializer.JsonSerializer<>(), new org.springframework.kafka.support.serializer.JsonDeserializer<>())));

        var alertsFromPayments = payments.filter((key, value) -> isThresholdExceeded(value));
        var alertsFromTransfers = transfers.filter((key, value) -> isThresholdExceeded(value));

        alertsFromPayments.mapValues(v -> Map.of("type","payment","alert","threshold_exceeded","payload",v))
                .to("alerts.suspect", Produced.with(Serdes.String(), Serdes.serdeFrom(new org.springframework.kafka.support.serializer.JsonSerializer<>(), new org.springframework.kafka.support.serializer.JsonDeserializer<>())));
        alertsFromTransfers.mapValues(v -> Map.of("type","transfer","alert","threshold_exceeded","payload",v))
                .to("alerts.suspect", Produced.with(Serdes.String(), Serdes.serdeFrom(new org.springframework.kafka.support.serializer.JsonSerializer<>(), new org.springframework.kafka.support.serializer.JsonDeserializer<>())));

        return builder.build();
    }

    private boolean isThresholdExceeded(Object value) {
        if (value instanceof Map<?,?> m) {
            Object amount = m.get("amount");
            if (amount instanceof Number n) {
                return n.doubleValue() >= getThreshold();
            }
        }
        return false;
    }

    private double getThreshold() {
        String env = System.getenv().getOrDefault("ALERT_THRESHOLD","10000");
        try { return Double.parseDouble(env); } catch (Exception e) { return 10000d; }
    }
}