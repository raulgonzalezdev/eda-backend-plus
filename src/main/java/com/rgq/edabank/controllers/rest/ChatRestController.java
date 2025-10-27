package com.rgq.edabank.controllers.rest;

import com.rgq.edabank.dto.ConversationDto;
import com.rgq.edabank.dto.MessageDto;
import com.rgq.edabank.mappers.ChatMapper;
import com.rgq.edabank.repositories.ConversationRepository;
import com.rgq.edabank.repositories.MessageRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/chat")
public class ChatRestController {

    @Autowired
    private ConversationRepository conversationRepository;

    @Autowired
    private MessageRepository messageRepository;

    @GetMapping("/conversations")
    public List<ConversationDto> getConversations() {
        return conversationRepository.findAll()
                .stream()
                .map(ChatMapper::toDto)
                .collect(Collectors.toList());
    }

    @GetMapping("/conversations/{id}")
    public ConversationDto getConversation(@PathVariable Long id) {
        return conversationRepository.findById(id)
                .map(ChatMapper::toDto)
                .orElse(null);
    }

    @GetMapping("/conversations/{id}/messages")
    public List<MessageDto> getMessages(@PathVariable Long id) {
        // This is a simplified implementation. In a real application, you would
        // want to add pagination and proper error handling.
        return ChatMapper.toDto(messageRepository.findByConversationId(id));
    }
}