package com.rgq.edabank.controller;

import com.rgq.edabank.model.User;
import com.rgq.edabank.service.JwtService;
import com.rgq.edabank.service.UserService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.HashMap;

@RestController
public class UserController {

    private static final Logger log = LoggerFactory.getLogger(UserController.class);
    private final UserService userService;
    private final JwtService jwtService;

    public UserController(UserService userService, JwtService jwtService) {
        this.userService = userService;
        this.jwtService = jwtService;
    }

    @GetMapping("/users")
    public ResponseEntity<?> list() {
        try {
            var users = userService.findAll();
            List<Map<String,Object>> out = users.stream().map(u -> {
                Map<String,Object> m = new HashMap<>();
                m.put("id", u.getId());
                m.put("email", u.getEmail());
                m.put("firstName", u.getFirstName());
                m.put("lastName", u.getLastName());
                m.put("role", u.getRole());
                return m;
            }).collect(Collectors.toList());
            return ResponseEntity.ok(out);
        } catch (Exception e) {
            log.error("Error fetching users list", e);
            return ResponseEntity.status(500).body("Error fetching users");
        }
    }

    @GetMapping("/users/{id}")
    public ResponseEntity<?> get(@PathVariable UUID id) {
        try {
            Optional<User> u = userService.findById(id);
            return u.map(user -> ResponseEntity.ok(Map.of(
                    "id", user.getId(),
                    "email", user.getEmail(),
                    "firstName", user.getFirstName(),
                    "lastName", user.getLastName(),
                    "role", user.getRole()
            ))).orElseGet(() -> ResponseEntity.notFound().build());
        } catch (Exception e) {
            log.error("Error fetching user with id={}", id, e);
            return ResponseEntity.status(500).body("Error fetching user");
        }
    }

    @PostMapping("/users")
    public ResponseEntity<?> create(@RequestBody Map<String, Object> body) {
        try {
            String email = (String) body.get("email");
            String password = (String) body.get("password");
            if (email == null || password == null) {
                return ResponseEntity.badRequest().body("email and password required");
            }
            User u = new User();
            u.setEmail(email);
            u.setFirstName((String) body.get("firstName"));
            u.setLastName((String) body.get("lastName"));
            u.setRole((String) body.getOrDefault("role", "PATIENT"));
            // check uniqueness
            if (userService.findByEmail(email).isPresent()) {
                return ResponseEntity.status(409).body("email already exists");
            }
            userService.create(u, password);
            return ResponseEntity.ok(Map.of(
                "id", u.getId(),
                "email", u.getEmail(),
                "firstName", u.getFirstName(),
                "lastName", u.getLastName(),
                "role", u.getRole()
            ));
        } catch (Exception e) {
            log.error("Error creating user", e);
            return ResponseEntity.status(500).body("Error creating user");
        }
    }

    @PutMapping("/users/{id}")
    public ResponseEntity<?> update(@PathVariable UUID id, @RequestBody Map<String, Object> body) {
        try {
            Optional<User> ou = userService.findById(id);
            if (ou.isEmpty()) {
                return ResponseEntity.notFound().build();
            }
            User u = ou.get();
            u.setEmail((String) body.getOrDefault("email", u.getEmail()));
            u.setFirstName((String) body.getOrDefault("firstName", u.getFirstName()));
            u.setLastName((String) body.getOrDefault("lastName", u.getLastName()));
            u.setRole((String) body.getOrDefault("role", u.getRole()));
            String newPass = (String) body.get("password");
            userService.update(u, newPass);
            return ResponseEntity.ok(Map.of(
                "id", u.getId(),
                "email", u.getEmail(),
                "firstName", u.getFirstName(),
                "lastName", u.getLastName(),
                "role", u.getRole()
            ));
        } catch (Exception e) {
            log.error("Error updating user with id={}", id, e);
            return ResponseEntity.status(500).body("Error updating user");
        }
    }

    @DeleteMapping("/users/{id}")
    public ResponseEntity<?> delete(@PathVariable UUID id) {
        int r = userService.delete(id);
        return ResponseEntity.ok(Map.of("deleted", r));
    }

    @PostMapping("/auth/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> body) throws Exception {
        String email = body.get("email");
        String password = body.get("password");
        if (email == null || password == null) return ResponseEntity.badRequest().body("email and password required");
        var ou = userService.findByEmail(email);
        if (ou.isEmpty()) return ResponseEntity.status(401).body("invalid credentials");
        var user = ou.get();
        if (!userService.verifyPassword(user, password)) return ResponseEntity.status(401).body("invalid credentials");
        String token = jwtService.createToken(user.getEmail(), "user");
        return ResponseEntity.ok(Map.of("token", token));
    }
}
