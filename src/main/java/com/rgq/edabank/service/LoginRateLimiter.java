package com.rgq.edabank.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class LoginRateLimiter {
    private final ConcurrentHashMap<String, Deque<Long>> buckets = new ConcurrentHashMap<>();
    private final int maxAttempts = 5;
    private final long windowMs = 60_000; // 1 minuto

    @Autowired(required = false)
    private StringRedisTemplate redis;

    public boolean tryAcquire(String key) {
        // Si Redis está disponible, usar contador con TTL
        try {
            if (redis != null) {
                String rkey = "login:rate:" + key;
                Long count = redis.opsForValue().increment(rkey);
                if (count != null && count == 1L) {
                    redis.expire(rkey, Duration.ofMillis(windowMs));
                }
                if (count != null && count > maxAttempts) {
                    return false;
                }
                return true;
            }
        } catch (Exception ignored) { /* fallback abajo */ }

        // Fallback a memoria local
        long now = System.currentTimeMillis();
        Deque<Long> q = buckets.computeIfAbsent(key, k -> new ArrayDeque<>());
        // prune
        while (!q.isEmpty() && now - q.peekFirst() > windowMs) {
            q.pollFirst();
        }
        if (q.size() >= maxAttempts) {
            return false;
        }
        q.addLast(now);
        return true;
    }
}