package com.rgq.edabank.models;

import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
public class ChatMessage {
    private String content;
    private String sender;
    private MessageType type;
    private Long conversationId;
    private LocalDateTime sentAt;

    public enum MessageType {
        CHAT,
        JOIN,
        LEAVE
    }
}