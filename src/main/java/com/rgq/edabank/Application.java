package com.rgq.edabank;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.kafka.annotation.EnableKafkaStreams;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.transaction.annotation.EnableTransactionManagement;

import org.springframework.boot.autoconfigure.domain.EntityScan;

@SpringBootApplication
@EnableTransactionManagement
@EnableKafkaStreams
@EnableScheduling
@EntityScan("com.sas.domain")
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
