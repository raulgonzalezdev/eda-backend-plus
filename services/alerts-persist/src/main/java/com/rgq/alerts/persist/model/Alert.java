package com.rgq.alerts.persist.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "alerts", schema = "pos")
public class Alert {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "event_id")
    private String eventId;
    @Column(name = "alert_type")
    private String alertType;
    @Column(name = "source_type")
    private String sourceType;
    @Column(name = "amount")
    private Double amount;
    @JdbcTypeCode(SqlTypes.JSON)
    private String payload;
    @Column(name = "tenant_id")
    private String tenantId;
    @Column(name = "kafka_partition")
    private Integer kafkaPartition;
    @Column(name = "kafka_offset")
    private Long kafkaOffset;
    @CreationTimestamp
    @Column(name = "created_at")
    private OffsetDateTime createdAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getEventId() { return eventId; }
    public void setEventId(String eventId) { this.eventId = eventId; }
    public String getAlertType() { return alertType; }
    public void setAlertType(String alertType) { this.alertType = alertType; }
    public String getSourceType() { return sourceType; }
    public void setSourceType(String sourceType) { this.sourceType = sourceType; }
    public Double getAmount() { return amount; }
    public void setAmount(Double amount) { this.amount = amount; }
    public String getPayload() { return payload; }
    public void setPayload(String payload) { this.payload = payload; }
    public String getTenantId() { return tenantId; }
    public void setTenantId(String tenantId) { this.tenantId = tenantId; }
    public Integer getKafkaPartition() { return kafkaPartition; }
    public void setKafkaPartition(Integer kafkaPartition) { this.kafkaPartition = kafkaPartition; }
    public Long getKafkaOffset() { return kafkaOffset; }
    public void setKafkaOffset(Long kafkaOffset) { this.kafkaOffset = kafkaOffset; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
}