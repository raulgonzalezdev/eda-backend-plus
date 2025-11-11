package com.rgq.edabank.dto.ws;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.OffsetDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OutboundChatMessageDto {
    private String content;
    private String sender;
    private String type; // CHAT | JOIN | LEAVE
    private Long conversationId;
    private OffsetDateTime sentAt;
}