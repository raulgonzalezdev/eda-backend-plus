package com.rgq.edabank.controller;

import com.rgq.edabank.config.TestJpaConfig;
import com.rgq.edabank.repository.AlertsRepository;
import com.rgq.edabank.repository.ConversationRepository;
import com.rgq.edabank.repository.MessageRepository;
import com.rgq.edabank.repository.OutboxRepository;
import com.rgq.edabank.repository.PaymentRepository;
import com.rgq.edabank.repository.TransferRepository;
import com.rgq.edabank.repository.UserRepository;
import com.rgq.edabank.model.User;
import com.rgq.edabank.service.JwtService;
import com.rgq.edabank.service.UserService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.UUID;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(value = UserController.class, excludeAutoConfiguration = {
        org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration.class,
        org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration.class,
        org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration.class
})
@AutoConfigureMockMvc(addFilters = false)
@Import({TestJpaConfig.class})
class UserControllerListTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @MockBean
    private JwtService jwtService;

    // Mock all JPA repositories to prevent JPA initialization in slice tests
    @MockBean private AlertsRepository alertsRepository;
    @MockBean private ConversationRepository conversationRepository;
    @MockBean private MessageRepository messageRepository;
    @MockBean private OutboxRepository outboxRepository;
    @MockBean private PaymentRepository paymentRepository;
    @MockBean private TransferRepository transferRepository;
    @MockBean private UserRepository userRepository;

    @Test
    void listReturnsUsersDto() throws Exception {
        User u = new User();
        u.setId(UUID.fromString("11111111-1111-1111-1111-111111111111"));
        u.setEmail("user@example.com");
        u.setFirstName("Unit");
        u.setLastName("Test");
        u.setRole("user");
        u.setHashedPassword("hash");

        when(userService.findAll()).thenReturn(List.of(u));

        mockMvc.perform(get("/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value("11111111-1111-1111-1111-111111111111"))
                .andExpect(jsonPath("$[0].email").value("user@example.com"))
                .andExpect(jsonPath("$[0].firstName").value("Unit"))
                .andExpect(jsonPath("$[0].lastName").value("Test"))
                .andExpect(jsonPath("$[0].role").value("user"));
    }

}