package com.rgq.alerts.config.dto;

public class RuleDto {
    private String type;
    private Double threshold;
    private Boolean enabled;

    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public Double getThreshold() { return threshold; }
    public void setThreshold(Double threshold) { this.threshold = threshold; }
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
}