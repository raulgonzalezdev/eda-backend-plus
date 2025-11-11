package com.rgq.edabank.config;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.kafka.annotation.KafkaStreamsDefaultConfiguration;
import org.springframework.kafka.config.KafkaStreamsConfiguration;

import java.util.HashMap;
import java.util.Map;

@TestConfiguration
public class TestKafkaStreamsConfig {

    @Bean(name = KafkaStreamsDefaultConfiguration.DEFAULT_STREAMS_CONFIG_BEAN_NAME)
    public KafkaStreamsConfiguration defaultKafkaStreamsConfig() {
        Map<String, Object> props = new HashMap<>();
        props.put(org.apache.kafka.streams.StreamsConfig.APPLICATION_ID_CONFIG, "test-app");
        props.put(org.apache.kafka.clients.CommonClientConfigs.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
        return new KafkaStreamsConfiguration(props);
    }
}