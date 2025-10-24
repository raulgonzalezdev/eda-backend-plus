package com.rgq.edabank.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "outbox", schema = "pos")
public class Outbox {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "aggregate_type")
    private String aggregateType;
    @Column(name = "aggregate_id")
    private String aggregateId;
    @Column(name = "event_type")
    private String eventType;
    @JdbcTypeCode(SqlTypes.JSON)
    private String payload;
    private Boolean sent;
    @Column(name = "created_at")
    private OffsetDateTime createdAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getAggregateType() { return aggregateType; }
    public void setAggregateType(String aggregateType) { this.aggregateType = aggregateType; }
    public String getAggregateId() { return aggregateId; }
    public void setAggregateId(String aggregateId) { this.aggregateId = aggregateId; }
    public String getEventType() { return eventType; }
    public void setEventType(String eventType) { this.eventType = eventType; }
    
    // Alias methods for compatibility with existing code
    public String getType() { return eventType; }
    public void setType(String type) { this.eventType = type; }
    
    public String getPayload() { return payload; }
    public void setPayload(String payload) { this.payload = payload; }
    public Boolean getSent() { return sent; }
    public void setSent(Boolean sent) { this.sent = sent; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
}
