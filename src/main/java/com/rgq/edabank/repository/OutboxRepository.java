package com.rgq.edabank.repository;

import com.rgq.edabank.model.Outbox;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Repository
public interface OutboxRepository extends JpaRepository<Outbox, Long> {

    @Transactional(readOnly = true)
    List<Outbox> findBySentFalseOrderByCreatedAtAsc();

    @Modifying
    @Query("update Outbox o set o.sent = true where o.id = ?1")
    void markSent(Long id);
}