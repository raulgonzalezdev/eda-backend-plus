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
        var users = userService.findAll();
        List<UserDto> out = users.stream().map(this::convertToDto).collect(Collectors.toList());
        return ResponseEntity.ok(out);
    }

    @GetMapping("/users/{id}")
    public ResponseEntity<UserDto> get(@PathVariable UUID id) {
        Optional<User> u = userService.findById(id);
        return u.map(user -> ResponseEntity.ok(convertToDto(user))).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping("/users")
    public ResponseEntity<?> create(@RequestBody UserDto body) {
        String email = body.getEmail();
        String password = body.getPassword();
        if (email == null || password == null) return ResponseEntity.badRequest().body("email and password required");
        User u = new User();
        u.setEmail(email);
        u.setFirstName(body.getFirstName());
        u.setLastName(body.getLastName());
        u.setRole(body.getRole() != null ? body.getRole() : "PATIENT");
        // check uniqueness
        if (userService.findByEmail(email).isPresent()) {
            return ResponseEntity.status(409).body("email already exists");
        }
        User savedUser = userService.create(u, password);
        return ResponseEntity.ok(convertToDto(savedUser));
    }

    @PutMapping("/users/{id}")
    public ResponseEntity<?> update(@PathVariable UUID id, @RequestBody UserDto body) {
        Optional<User> ou = userService.findById(id);
        if (ou.isEmpty()) return ResponseEntity.notFound().build();
        User u = ou.get();
        u.setEmail(body.getEmail() != null ? body.getEmail() : u.getEmail());
        u.setFirstName(body.getFirstName() != null ? body.getFirstName() : u.getFirstName());
        u.setLastName(body.getLastName() != null ? body.getLastName() : u.getLastName());
        u.setRole(body.getRole() != null ? body.getRole() : u.getRole());
        String newPass = body.getPassword();
        User savedUser = userService.update(u, newPass);
        return ResponseEntity.ok(convertToDto(savedUser));
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

    private UserDto convertToDto(User user) {
        return new UserDto(user.getId(), user.getEmail(), user.getFirstName(), user.getLastName(), user.getRole());
    }
}
