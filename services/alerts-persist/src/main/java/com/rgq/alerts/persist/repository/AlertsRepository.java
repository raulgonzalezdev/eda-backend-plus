package com.rgq.alerts.persist.repository;

import com.rgq.alerts.persist.model.Alert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Repository
public interface AlertsRepository extends JpaRepository<Alert, Long> {
    @Transactional(readOnly = true)
    List<Alert> findTop100ByOrderByCreatedAtDesc();
    @Transactional(readOnly = true)
    List<Alert> findTop100ByTenantIdOrderByCreatedAtDesc(String tenantId);
}