package com.rgq.edabank.service;

import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class CaptchaService {

    private static class Challenge {
        String question;
        int answer;
        Instant expiresAt;
    }

    public static class CaptchaChallenge {
        public String token;
        public String question;
        public long expiresInSeconds;
    }

    private final ConcurrentHashMap<String, Challenge> store = new ConcurrentHashMap<>();
    private final Random random = new Random();
    private final long ttlSeconds = 120; // 2 minutos

    public CaptchaChallenge generate() {
        int a = 10 + random.nextInt(90);
        int b = 1 + random.nextInt(9);
        int op = random.nextInt(2); // 0:+ 1:-
        int result = (op == 0) ? (a + b) : (a - b);
        String symbol = (op == 0) ? "+" : "-";

        String token = UUID.randomUUID().toString();
        Challenge c = new Challenge();
        c.question = String.format("¿Cuánto es %d %s %d?", a, symbol, b);
        c.answer = result;
        c.expiresAt = Instant.now().plusSeconds(ttlSeconds);
        store.put(token, c);

        CaptchaChallenge out = new CaptchaChallenge();
        out.token = token;
        out.question = c.question;
        out.expiresInSeconds = ttlSeconds;
        return out;
    }

    public boolean validate(String token, String answerRaw) {
        if (token == null || answerRaw == null) return false;
        Challenge c = store.get(token);
        if (c == null) return false;
        if (Instant.now().isAfter(c.expiresAt)) {
            store.remove(token);
            return false;
        }
        try {
            int ans = Integer.parseInt(answerRaw.trim());
            boolean ok = (ans == c.answer);
            if (ok) store.remove(token);
            return ok;
        } catch (NumberFormatException e) {
            return false;
        }
    }
}