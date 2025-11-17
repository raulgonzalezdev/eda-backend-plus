package com.rgq.alerts.persist.repository;

import com.rgq.alerts.persist.model.Alert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface AlertsRepository extends JpaRepository<Alert, Long> {
}