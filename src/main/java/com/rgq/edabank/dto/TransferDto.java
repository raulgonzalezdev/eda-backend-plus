package com.rgq.edabank.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public class TransferDto {
    @NotBlank
    private String id;
    private String type;
    @NotNull @Positive
    private Double amount;
    private String from;
    private String to;

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public Double getAmount() { return amount; }
    public void setAmount(Double amount) { this.amount = amount; }
    public String getFrom() { return from; }
    public void setFrom(String from) { this.from = from; }
    public String getTo() { return to; }
    public void setTo(String to) { this.to = to; }

    @Override
    public String toString() {
        return "TransferDto{" +
                "id='" + id + '\'' +
                ", type='" + type + '\'' +
                ", amount=" + amount +
                ", from='" + from + '\'' +
                ", to='" + to + '\'' +
                '}';
    }
}
