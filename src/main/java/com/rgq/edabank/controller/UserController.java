package com.rgq.edabank.controller;

import com.rgq.edabank.dto.UserDto;
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

@RestController
public class UserController {

    private final UserService userService;
    private final JwtService jwtService;

    public UserController(UserService userService, JwtService jwtService) {
        this.userService = userService;
        this.jwtService = jwtService;
    }

    @GetMapping("/users")
    public ResponseEntity<List<UserDto>> list() {
        List<UserDto> users = userService.findAll().stream()
                .map(this::convertToDto)
                .collect(Collectors.toList());
        return ResponseEntity.ok(users);
    }

    @GetMapping("/users/{id}")
    public ResponseEntity<UserDto> get(@PathVariable UUID id) {
        Optional<User> user = userService.findById(id);
        return user.map(u -> ResponseEntity.ok(convertToDto(u)))
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/users")
    public ResponseEntity<?> create(@RequestBody UserDto body) {
        try {
            User user = new User();
            user.setEmail(body.getEmail());
            user.setFirstName(body.getFirstName());
            user.setLastName(body.getLastName());
            user.setRole(body.getRole());
            
            User created = userService.create(user, body.getPassword());
            return ResponseEntity.ok(convertToDto(created));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error creating user: " + e.getMessage());
        }
    }

    @PutMapping("/users/{id}")
    public ResponseEntity<?> update(@PathVariable UUID id, @RequestBody UserDto body) {
        try {
            Optional<User> existingUser = userService.findById(id);
            if (existingUser.isEmpty()) {
                return ResponseEntity.notFound().build();
            }
            
            User user = existingUser.get();
            user.setEmail(body.getEmail());
            user.setFirstName(body.getFirstName());
            user.setLastName(body.getLastName());
            user.setRole(body.getRole());
            
            User updated = userService.update(user, body.getPassword());
            return ResponseEntity.ok(convertToDto(updated));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error updating user: " + e.getMessage());
        }
    }

    @DeleteMapping("/users/{id}")
    public ResponseEntity<?> delete(@PathVariable UUID id) {
        try {
            userService.delete(id);
            return ResponseEntity.ok().build();
        } catch (Exception e) {
            return ResponseEntity.badRequest().body("Error deleting user: " + e.getMessage());
        }
    }

    @PostMapping("/auth/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> body) throws Exception {
        String email = body.get("email");
        String password = body.get("password");
        if (email == null || password == null) {
            return ResponseEntity.badRequest().body("email and password required");
        }
        
        Optional<User> ou = userService.findByEmail(email);
        if (ou.isEmpty()) {
            return ResponseEntity.status(401).body("invalid credentials");
        }
        
        User user = ou.get();
        if (!userService.verifyPassword(user, password)) {
            return ResponseEntity.status(401).body("invalid credentials");
        }
        
        String token = jwtService.createToken(user.getEmail(), "user");
        return ResponseEntity.ok(Map.of("token", token));
    }

    private UserDto convertToDto(User user) {
        return new UserDto(user.getId(), user.getEmail(), user.getFirstName(), user.getLastName(), user.getRole());
    }
}
