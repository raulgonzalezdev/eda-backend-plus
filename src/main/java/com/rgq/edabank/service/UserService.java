package com.rgq.edabank.service;

import com.rgq.edabank.model.User;
import com.rgq.edabank.repository.UserRepository;
import org.springframework.security.crypto.bcrypt.BCrypt;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class UserService {

    private final UserRepository repo;

    public UserService(UserRepository repo) {
        this.repo = repo;
    }

    @Transactional(readOnly = true)
    public List<User> findAll() { return repo.findAll(); }

    @Transactional(readOnly = true)
    public Optional<User> findById(UUID id) { return repo.findById(id); }

    @Transactional(readOnly = true)
    public Optional<User> findByEmail(String email) { return repo.findByEmail(email); }

    public User create(User u, String plainPassword) {
        u.setHashedPassword(BCrypt.hashpw(plainPassword, BCrypt.gensalt()));
        return repo.save(u);
    }

    public User update(User u, String plainPassword) {
        if (plainPassword != null && !plainPassword.isEmpty()) {
            u.setHashedPassword(BCrypt.hashpw(plainPassword, BCrypt.gensalt()));
        }
        return repo.save(u);
    }

    public void delete(UUID id) { repo.deleteById(id); }

    public boolean verifyPassword(User u, String plain) {
        return u != null && BCrypt.checkpw(plain, u.getHashedPassword());
    }
}
