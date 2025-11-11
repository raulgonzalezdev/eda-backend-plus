package com.rgq.edabank.controller;

import com.rgq.edabank.config.TestJpaConfig;
import com.rgq.edabank.repository.AlertsRepository;
import com.rgq.edabank.repository.ConversationRepository;
import com.rgq.edabank.repository.MessageRepository;
import com.rgq.edabank.repository.OutboxRepository;
import com.rgq.edabank.repository.PaymentRepository;
import com.rgq.edabank.repository.TransferRepository;
import com.rgq.edabank.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;

@WebMvcTest(value = AuthController.class, excludeAutoConfiguration = {
        org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration.class,
        org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration.class,
        org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration.class
})
@AutoConfigureMockMvc(addFilters = false)
@Import({TestJpaConfig.class})
@TestPropertySource(properties = {
        "app.jwt.secret=test-secret"
})
class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean private AlertsRepository alertsRepository;
    @MockBean private ConversationRepository conversationRepository;
    @MockBean private MessageRepository messageRepository;
    @MockBean private OutboxRepository outboxRepository;
    @MockBean private PaymentRepository paymentRepository;
    @MockBean private TransferRepository transferRepository;
    @MockBean private UserRepository userRepository;

    @Test
    void tokenEndpointReturnsJwt() throws Exception {
        mockMvc.perform(get("/auth/token")
                        .param("sub", "unit-user")
                        .param("scope", "alerts.read"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.matchesPattern("^[A-Za-z0-9-_]+\\.[A-Za-z0-9-_]+\\.[A-Za-z0-9-_]+$")));
    }

}