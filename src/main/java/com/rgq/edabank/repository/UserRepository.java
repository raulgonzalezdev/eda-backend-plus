package com.rgq.edabank.repository;

import com.rgq.edabank.model.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class UserRepository {

    private static final Logger log = LoggerFactory.getLogger(UserRepository.class);
    private final JdbcTemplate jdbc;

    public UserRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private final RowMapper<User> mapper = new RowMapper<>() {
        @Override
        public User mapRow(ResultSet rs, int rowNum) throws SQLException {
            User u = new User();
            u.setId((UUID) rs.getObject("id"));
            u.setEmail(rs.getString("email"));
            u.setHashedPassword(rs.getString("hashed_password"));
            u.setRole(rs.getString("role"));
            u.setFirstName(rs.getString("first_name"));
            u.setLastName(rs.getString("last_name"));
            return u;
        }
    };

    public List<User> findAll() {
        log.debug("Querying all users");
        return jdbc.query("SELECT id,email,hashed_password,role,first_name,last_name FROM users", mapper);
    }

    public Optional<User> findById(UUID id) {
        log.debug("Querying user by id={}", id);
        List<User> l = jdbc.query("SELECT id,email,hashed_password,role,first_name,last_name FROM users WHERE id = ?", new Object[]{id}, mapper);
        return l.isEmpty() ? Optional.empty() : Optional.of(l.get(0));
    }

    public Optional<User> findByEmail(String email) {
        log.debug("Querying user by email={}", email);
        List<User> l = jdbc.query("SELECT id,email,hashed_password,role,first_name,last_name FROM users WHERE email = ?", new Object[]{email}, mapper);
        return l.isEmpty() ? Optional.empty() : Optional.of(l.get(0));
    }

    public void insert(User u) {
        log.debug("Inserting user id={}, email={}", u.getId(), u.getEmail());
        jdbc.update("INSERT INTO users (id,email,hashed_password,role,first_name,last_name) VALUES (?,?,?,?,?,?)",
                u.getId(), u.getEmail(), u.getHashedPassword(), u.getRole(), u.getFirstName(), u.getLastName());
    }

    public int update(User u) {
        log.debug("Updating user id={}", u.getId());
        return jdbc.update("UPDATE users SET email=?, hashed_password=?, role=?, first_name=?, last_name=? WHERE id=?",
                u.getEmail(), u.getHashedPassword(), u.getRole(), u.getFirstName(), u.getLastName(), u.getId());
    }

    public int delete(UUID id) {
        log.debug("Deleting user id={}", id);
        return jdbc.update("DELETE FROM users WHERE id=?", id);
    }
}