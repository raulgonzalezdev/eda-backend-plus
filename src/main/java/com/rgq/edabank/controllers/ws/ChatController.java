package com.rgq.edabank.controllers.ws;

import com.rgq.edabank.dto.ws.InboundChatMessageDto;
import com.rgq.edabank.services.ChatService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Controller;

@Controller
public class ChatController {

    @Autowired
    private ChatService chatService;

    @MessageMapping("/chat.sendMessage")
    public void sendMessage(@Payload InboundChatMessageDto chatMessage) {
        chatService.sendMessage(chatMessage);
    }
}