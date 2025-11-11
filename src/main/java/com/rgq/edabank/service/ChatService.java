package com.rgq.edabank.service;

import com.rgq.edabank.dto.ws.InboundChatMessageDto;
import com.rgq.edabank.dto.ws.OutboundChatMessageDto;
import com.rgq.edabank.model.ChatMessage;
import com.rgq.edabank.model.Conversation;
import com.rgq.edabank.model.Message;
import com.rgq.edabank.repository.ConversationRepository;
import com.rgq.edabank.repository.MessageRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;

@Service
public class ChatService {
    private static final Logger log = LoggerFactory.getLogger(ChatService.class);

    @Autowired
    private KafkaTemplate<String, Object> kafkaTemplate;

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @Autowired
    private MessageRepository messageRepository;

    @Autowired
    private ConversationRepository conversationRepository;

    @Value("${app.kafka.topics.chat}")
    private String chatTopic;

    public Long sendMessage(InboundChatMessageDto input) {
        log.info("[CHAT] Enviando mensaje: sender={}, type={}, convId={}", input.getSender(), input.getType(), input.getConversationId());
        Long convId = input.getConversationId();
        Conversation conversation = null;
        if (convId != null) {
            conversation = conversationRepository.findById(convId).orElse(null);
        }
        if (conversation == null) {
            conversation = Conversation.builder().createdAt(LocalDateTime.now()).build();
            conversation = conversationRepository.save(conversation);
        }

        LocalDateTime now = LocalDateTime.now();
        Message message = Message.builder()
                .content(input.getContent())
                .sender(input.getSender())
                .sentAt(now)
                .conversation(conversation)
                .build();

        messageRepository.save(message);

        ChatMessage.MessageType type = ChatMessage.MessageType.CHAT;
        if (input.getType() != null) {
            try { type = ChatMessage.MessageType.valueOf(input.getType()); } catch (Exception ignored) {}
        }

        ChatMessage event = ChatMessage.builder()
                .content(input.getContent())
                .sender(input.getSender())
                .type(type)
                .conversationId(conversation.getId())
                .sentAt(OffsetDateTime.now())
                .build();

        kafkaTemplate.send(chatTopic, event);
        log.info("[CHAT] Mensaje publicado en Kafka topic={} convId={}", chatTopic, conversation.getId());
        return conversation.getId();
    }

    @KafkaListener(topics = "${app.kafka.topics.chat}", groupId = "chat-ui", containerFactory = "jsonKafkaListenerContainerFactory")
    public void listen(ChatMessage chatMessage) {
        log.info("[CHAT] Consumido de Kafka: sender={}, type={}, convId={}", chatMessage.getSender(), chatMessage.getType(), chatMessage.getConversationId());
        OutboundChatMessageDto out = OutboundChatMessageDto.builder()
                .content(chatMessage.getContent())
                .sender(chatMessage.getSender())
                .type(chatMessage.getType() != null ? chatMessage.getType().name() : null)
                .conversationId(chatMessage.getConversationId())
                .sentAt(chatMessage.getSentAt())
                .build();
        messagingTemplate.convertAndSend("/topic/public", out);
        log.info("[CHAT] Emitido por WebSocket a /topic/public: sender={} convId={}", chatMessage.getSender(), chatMessage.getConversationId());
    }
}