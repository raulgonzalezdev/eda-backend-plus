package com.rgq.alerts.streams;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.kafka.annotation.EnableKafkaStreams;

@SpringBootApplication
@EnableKafkaStreams
public class StreamsApplication {
    public static void main(String[] args) {
        SpringApplication.run(StreamsApplication.class, args);
    }
}