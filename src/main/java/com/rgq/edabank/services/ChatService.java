package com.rgq.edabank.services;

import com.rgq.edabank.dto.ws.InboundChatMessageDto;
import com.rgq.edabank.dto.ws.OutboundChatMessageDto;
import com.rgq.edabank.models.ChatMessage;
import com.rgq.edabank.models.Conversation;
import com.rgq.edabank.models.Message;
import com.rgq.edabank.repositories.ConversationRepository;
import com.rgq.edabank.repositories.MessageRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
public class ChatService {

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

    public void sendMessage(InboundChatMessageDto input) {
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
                .sentAt(now)
                .build();

        kafkaTemplate.send(chatTopic, event);
    }

    @KafkaListener(topics = "${app.kafka.topics.chat}", groupId = "chat")
    public void listen(ChatMessage chatMessage) {
        OutboundChatMessageDto out = OutboundChatMessageDto.builder()
                .content(chatMessage.getContent())
                .sender(chatMessage.getSender())
                .type(chatMessage.getType() != null ? chatMessage.getType().name() : null)
                .conversationId(chatMessage.getConversationId())
                .sentAt(chatMessage.getSentAt())
                .build();
        messagingTemplate.convertAndSend("/topic/public", out);
    }
}