package com.rgq.edabank.repository;

import com.rgq.edabank.model.Alert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AlertsRepository extends JpaRepository<Alert, Long> {

    List<Alert> findTop100ByOrderByCreatedAtDesc();

}