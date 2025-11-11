package com.rgq.edabank.model;

import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.time.OffsetDateTime;

@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatMessage {
    private String content;
    private String sender;
    private MessageType type;
    private Long conversationId;
    private OffsetDateTime sentAt;

    public enum MessageType {
        CHAT,
        JOIN,
        LEAVE
    }
}