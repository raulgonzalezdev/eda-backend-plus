package com.rgq.edabank.model;

import java.time.OffsetDateTime;

public class Alert {
    private Long id;
    private String eventId;
    private String alertType;
    private String sourceType;
    private double amount;
    private String payload;
    private Integer kafkaPartition;
    private Long kafkaOffset;
    private OffsetDateTime createdAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getEventId() { return eventId; }
    public void setEventId(String eventId) { this.eventId = eventId; }
    public String getAlertType() { return alertType; }
    public void setAlertType(String alertType) { this.alertType = alertType; }
    public String getSourceType() { return sourceType; }
    public void setSourceType(String sourceType) { this.sourceType = sourceType; }
    public double getAmount() { return amount; }
    public void setAmount(double amount) { this.amount = amount; }
    public String getPayload() { return payload; }
    public void setPayload(String payload) { this.payload = payload; }
    public Integer getKafkaPartition() { return kafkaPartition; }
    public void setKafkaPartition(Integer kafkaPartition) { this.kafkaPartition = kafkaPartition; }
    public Long getKafkaOffset() { return kafkaOffset; }
    public void setKafkaOffset(Long kafkaOffset) { this.kafkaOffset = kafkaOffset; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
}
