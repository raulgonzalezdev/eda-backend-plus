package com.rgq.edabank.service;

import com.rgq.edabank.model.User;
import com.rgq.edabank.repository.UserRepository;
import org.springframework.security.crypto.bcrypt.BCrypt;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class UserService {

    private final UserRepository repo;

    public UserService(UserRepository repo) {
        this.repo = repo;
    }

    public List<User> findAll() { return repo.findAll(); }

    public Optional<User> findById(UUID id) { return repo.findById(id); }

    public Optional<User> findByEmail(String email) { return repo.findByEmail(email); }

    public User create(User u, String plainPassword) {
        u.setId(UUID.randomUUID());
        u.setHashedPassword(BCrypt.hashpw(plainPassword, BCrypt.gensalt()));
        repo.insert(u);
        return u;
    }

    public int update(User u, String plainPassword) {
        if (plainPassword != null && !plainPassword.isEmpty()) {
            u.setHashedPassword(BCrypt.hashpw(plainPassword, BCrypt.gensalt()));
        }
        return repo.update(u);
    }

    public int delete(UUID id) { return repo.delete(id); }

    public boolean verifyPassword(User u, String plain) {
        return u != null && BCrypt.checkpw(plain, u.getHashedPassword());
    }
}
