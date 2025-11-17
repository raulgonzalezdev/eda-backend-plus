package com.rgq.edabank.repository;

import com.rgq.edabank.model.Alert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import org.springframework.transaction.annotation.Transactional;

@Repository
public interface AlertsRepository extends JpaRepository<Alert, Long> {

    @Transactional(readOnly = true)
    List<Alert> findTop100ByOrderByCreatedAtDesc();

    @Transactional(readOnly = true)
    List<Alert> findTop100ByTenantIdOrderByCreatedAtDesc(String tenantId);

}