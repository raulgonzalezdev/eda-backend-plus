package com.rgq.alerts.config.dto;

public class RuleDto {
    private String type;
    private String tenantId; // opcional para multi‑tenancy
    private Double threshold;
    private Boolean enabled;

    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public String getTenantId() { return tenantId; }
    public void setTenantId(String tenantId) { this.tenantId = tenantId; }
    public Double getThreshold() { return threshold; }
    public void setThreshold(Double threshold) { this.threshold = threshold; }
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
}