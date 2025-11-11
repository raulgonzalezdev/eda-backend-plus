package com.rgq.edabank.config;

import org.mockito.Mockito;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.metamodel.Metamodel;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.AbstractPlatformTransactionManager;

@Configuration
public class TestJpaConfig {

    @Bean(name = "entityManagerFactory")
    public EntityManagerFactory entityManagerFactory() {
        Metamodel metamodel = Mockito.mock(Metamodel.class);
        EntityManagerFactory emf = Mockito.mock(EntityManagerFactory.class);
        Mockito.when(emf.getMetamodel()).thenReturn(metamodel);
        return emf;
    }

    @Bean
    public PlatformTransactionManager transactionManager() {
        return new NoopTransactionManager();
    }

    static class NoopTransactionManager extends AbstractPlatformTransactionManager {
        @Override
        protected Object doGetTransaction() {
            return new Object();
        }

        @Override
        protected void doBegin(Object transaction, org.springframework.transaction.TransactionDefinition definition) {
            // no-op
        }

        @Override
        protected void doCommit(org.springframework.transaction.support.DefaultTransactionStatus status) {
            // no-op
        }

        @Override
        protected void doRollback(org.springframework.transaction.support.DefaultTransactionStatus status) {
            // no-op
        }
    }
}