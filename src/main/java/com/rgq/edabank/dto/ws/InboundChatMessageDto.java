package com.rgq.edabank.dto.ws;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class InboundChatMessageDto {
    private String content;
    private String sender;
    private Long conversationId;
    private String type; // CHAT | JOIN | LEAVE (opcional)
}