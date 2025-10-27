package com.rgq.edabank.controller;

import com.rgq.edabank.model.User;
import com.rgq.edabank.service.JwtService;
import com.rgq.edabank.service.CaptchaService;
import com.rgq.edabank.service.LoginRateLimiter;
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
    private final CaptchaService captchaService;
    private final LoginRateLimiter loginRateLimiter;

    public UserController(UserService userService, JwtService jwtService, CaptchaService captchaService, LoginRateLimiter loginRateLimiter) {
        this.userService = userService;
        this.jwtService = jwtService;
        this.captchaService = captchaService;
        this.loginRateLimiter = loginRateLimiter;
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
    userService.create(u, password);
    return ResponseEntity.ok(Map.of(
        "id", u.getId(),
        "email", u.getEmail(),
        "firstName", u.getFirstName(),
        "lastName", u.getLastName(),
        "role", u.getRole()
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
    userService.update(u, newPass);
    return ResponseEntity.ok(Map.of(
        "id", u.getId(),
        "email", u.getEmail(),
        "firstName", u.getFirstName(),
        "lastName", u.getLastName(),
        "role", u.getRole()
    ));
    }

    @DeleteMapping("/users/{id}")
    public ResponseEntity<?> delete(@PathVariable UUID id) {
        int r = userService.delete(id);
        return ResponseEntity.ok(Map.of("deleted", r));
    }

    @PostMapping("/auth/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> body, jakarta.servlet.http.HttpServletRequest request) throws Exception {
        // Rate limiting por IP
        String ip = request.getHeader("X-Forwarded-For");
        if (ip != null && ip.contains(",")) ip = ip.split(",")[0].trim();
        if (ip == null || ip.isBlank()) ip = request.getRemoteAddr();
        if (!loginRateLimiter.tryAcquire(ip)) {
            return ResponseEntity.status(429).body("too many attempts, try again later");
        }

        // Validación CAPTCHA
        String captchaToken = body.get("captchaToken");
        String captchaAnswer = body.get("captchaAnswer");
        if (captchaToken == null || captchaAnswer == null) {
            return ResponseEntity.badRequest().body("captcha required");
        }
        if (!captchaService.validate(captchaToken, captchaAnswer)) {
            return ResponseEntity.status(401).body("invalid captcha");
        }

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

    @PostMapping("/auth/register")
    public ResponseEntity<?> register(@RequestBody Map<String, Object> body) throws Exception {
        String email = (String) body.get("email");
        String password = (String) body.get("password");
        if (email == null || password == null) {
            return ResponseEntity.badRequest().body("email and password required");
        }
        if (userService.findByEmail(email).isPresent()) {
            return ResponseEntity.status(409).body("email already exists");
        }

        User u = new User();
        u.setEmail(email);
        u.setFirstName((String) body.get("firstName"));
        u.setLastName((String) body.get("lastName"));
        u.setRole((String) body.getOrDefault("role", "PATIENT"));

        userService.create(u, password);

        long ttl = 900; // 15 minutos
        String token = jwtService.createToken(u.getEmail(), "user", ttl);

        return ResponseEntity.ok(Map.of(
                "id", u.getId(),
                "email", u.getEmail(),
                "firstName", u.getFirstName(),
                "lastName", u.getLastName(),
                "role", u.getRole(),
                "token", token,
                "tokenTtl", ttl
        ));
    }

    @GetMapping("/auth/captcha")
    public ResponseEntity<?> captcha() {
        var challenge = captchaService.generate();
        return ResponseEntity.ok(Map.of(
                "token", challenge.token,
                "question", challenge.question,
                "expiresIn", challenge.expiresInSeconds
        ));
    }
}
