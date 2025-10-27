package com.rgq.edabank.service;

import org.springframework.stereotype.Service;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class LoginRateLimiter {
    private final ConcurrentHashMap<String, Deque<Long>> buckets = new ConcurrentHashMap<>();
    private final int maxAttempts = 5;
    private final long windowMs = 60_000; // 1 minuto

    public boolean tryAcquire(String key) {
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