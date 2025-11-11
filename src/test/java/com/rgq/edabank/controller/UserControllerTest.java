package com.rgq.edabank.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
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
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(value = UserController.class, excludeAutoConfiguration = {
        org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration.class,
        org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration.class,
        org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration.class
})
@AutoConfigureMockMvc(addFilters = false)
@Import({TestJpaConfig.class})
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

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
    void loginReturnsTokenOnValidCredentials() throws Exception {
        String email = "user@example.com";
        String password = "secret";

        User user = new User();
        user.setId(UUID.randomUUID());
        user.setEmail(email);
        user.setFirstName("Unit");
        user.setLastName("Test");
        user.setRole("user");
        user.setHashedPassword("$2a$10$abcdefghijklmnopqrstuv1234567890abcdefghi"); // dummy

        when(userService.findByEmail(email)).thenReturn(Optional.of(user));
        when(userService.verifyPassword(user, password)).thenReturn(true);
        when(jwtService.createToken(email, "user")).thenReturn("mock.jwt.token");

        Map<String, String> body = Map.of("email", email, "password", password);

        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").value("mock.jwt.token"));
    }

    @Test
    void loginFailsWhenMissingFields() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

}