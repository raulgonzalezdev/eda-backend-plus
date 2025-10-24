package com.rgq.edabank.controller;

import com.rgq.edabank.model.User;
import com.rgq.edabank.service.JwtService;
import com.rgq.edabank.service.UserService;
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

    private final UserService userService;
    private final JwtService jwtService;

    public UserController(UserService userService, JwtService jwtService) {
        this.userService = userService;
        this.jwtService = jwtService;
    }

    @GetMapping("/users")
    public ResponseEntity<List<Map<String,Object>>> list() {
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
    }

    @GetMapping("/users/{id}")
    public ResponseEntity<?> get(@PathVariable UUID id) {
        Optional<User> u = userService.findById(id);
        return u.map(user -> ResponseEntity.ok(Map.of(
                "id", user.getId(),
                "email", user.getEmail(),
                "firstName", user.getFirstName(),
                "lastName", user.getLastName(),
                "role", user.getRole()
        ))).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping("/users")
    public ResponseEntity<?> create(@RequestBody Map<String, Object> body) {
        String email = (String) body.get("email");
        String password = (String) body.get("password");
        if (email == null || password == null) return ResponseEntity.badRequest().body("email and password required");
        User u = new User();
        u.setEmail(email);
        u.setFirstName((String) body.get("firstName"));
        u.setLastName((String) body.get("lastName"));
        u.setRole((String) body.getOrDefault("role", "PATIENT"));
    // check uniqueness
    if (userService.findByEmail(email).isPresent()) {
        return ResponseEntity.status(409).body("email already exists");
    }
    User savedUser = userService.create(u, password);
    return ResponseEntity.ok(Map.of(
        "id", savedUser.getId(),
        "email", savedUser.getEmail(),
        "firstName", savedUser.getFirstName(),
        "lastName", savedUser.getLastName(),
        "role", savedUser.getRole()
    ));
    }

    @PutMapping("/users/{id}")
    public ResponseEntity<?> update(@PathVariable UUID id, @RequestBody Map<String, Object> body) {
        Optional<User> ou = userService.findById(id);
        if (ou.isEmpty()) return ResponseEntity.notFound().build();
        User u = ou.get();
        u.setEmail((String) body.getOrDefault("email", u.getEmail()));
        u.setFirstName((String) body.getOrDefault("firstName", u.getFirstName()));
        u.setLastName((String) body.getOrDefault("lastName", u.getLastName()));
        u.setRole((String) body.getOrDefault("role", u.getRole()));
        String newPass = (String) body.get("password");
    User savedUser = userService.update(u, newPass);
    return ResponseEntity.ok(Map.of(
        "id", savedUser.getId(),
        "email", savedUser.getEmail(),
        "firstName", savedUser.getFirstName(),
        "lastName", savedUser.getLastName(),
        "role", savedUser.getRole()
    ));
    }

    @DeleteMapping("/users/{id}")
    public ResponseEntity<?> delete(@PathVariable UUID id) {
        userService.delete(id);
        return ResponseEntity.noContent().build();
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
