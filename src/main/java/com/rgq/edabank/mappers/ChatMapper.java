package com.rgq.edabank.mappers;

import com.rgq.edabank.dto.ConversationDto;
import com.rgq.edabank.dto.MessageDto;
import com.rgq.edabank.models.Conversation;
import com.rgq.edabank.models.Message;

import java.util.List;
import java.util.stream.Collectors;

public final class ChatMapper {

    private ChatMapper() {}

    public static ConversationDto toDto(Conversation c) {
        if (c == null) return null;
        return ConversationDto.builder()
                .id(c.getId())
                .createdAt(c.getCreatedAt())
                .build();
    }

    public static MessageDto toDto(Message m) {
        if (m == null) return null;
        return MessageDto.builder()
                .id(m.getId())
                .content(m.getContent())
                .sender(m.getSender())
                .sentAt(m.getSentAt())
                .conversationId(m.getConversation() != null ? m.getConversation().getId() : null)
                .build();
    }

    public static List<MessageDto> toDto(List<Message> messages) {
        return messages.stream().map(ChatMapper::toDto).collect(Collectors.toList());
    }
}