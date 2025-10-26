package com.rgq.events;

public class PaymentEvent {

    private String id;
    private double amount;

    public PaymentEvent() {
    }

    public PaymentEvent(String id, double amount) {
        this.id = id;
        this.amount = amount;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public double getAmount() {
        return amount;
    }

    public void setAmount(double amount) {
        this.amount = amount;
    }
}