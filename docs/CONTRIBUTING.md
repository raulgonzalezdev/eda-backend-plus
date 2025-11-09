# Contributing to the EDA Backend Plus

First off, thank you for considering contributing to this project! It's people like you that make this project such a great tool.

This document provides a guide for developers to contribute to this project. It outlines the architectural pattern, the structure of a feature, and the process for creating a new endpoint.

## Architectural Pattern

This project follows a classic layered architecture pattern, which is common in Spring Boot applications. The layers are:

- **Controller**: This layer is responsible for handling incoming HTTP requests, validating the input, and returning an appropriate HTTP response. It uses DTOs (Data Transfer Objects) to communicate with the client.
- **Service**: This layer contains the business logic of the application. It coordinates the interaction between the controller and the repository layers.
- **Repository**: This layer is responsible for data access. It interacts with the database to perform CRUD (Create, Read, Update, Delete) operations.
- **Model**: This layer represents the data model of the application. It's a plain Java object that maps to a database table.
- **DTO (Data Transfer Object)**: This layer is used to transfer data between the controller and the client. It helps to decouple the internal data model from the API that is exposed to the client.

## Feature Structure (User CRUD Example)

To illustrate the structure of a feature, let's take the example of a User CRUD (Create, Read, Update, Delete) feature.

### 1. Model (`User.java`)

The `User` model represents a user in the system. It's a JPA entity that maps to the `users` table in the database.

```java
package com.rgq.edabank.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "users", schema = "pos")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;
    private String email;
    @Column(name = "hashed_password")
    private String hashedPassword;
    private String role;
    @Column(name = "first_name")
    private String firstName;
    @Column(name = "last_name")
    private String lastName;

    public User() {}

    // Getters and setters
}
```

### 2. DTO (`UserDto.java`)

The `UserDto` is used to transfer user data between the client and the server. It doesn't include the `hashedPassword` for security reasons.

```java
package com.rgq.edabank.dto;

import java.util.UUID;

public class UserDto {
    private UUID id;
    private String email;
    private String firstName;
    private String lastName;
    private String role;
    private String password;

    public UserDto() {}

    public UserDto(UUID id, String email, String firstName, String lastName, String role) {
        this.id = id;
        this.email = email;
        this.firstName = firstName;
        this.lastName = lastName;
        this.role = role;
    }

    // Getters and setters
}
```

### 3. Repository (`UserRepository.java`)

The `UserRepository` provides the methods to interact with the `users` table in the database. It extends `JpaRepository`, which provides the basic CRUD operations.

```java
package com.rgq.edabank.repository;

import com.rgq.edabank.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {

    Optional<User> findByEmail(String email);

}
```

### 4. Service (`UserService.java`)

The `UserService` contains the business logic for the user feature. It uses the `UserRepository` to interact with the database.

```java
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
```

### 5. Controller (`UserController.java`)

The `UserController` handles the HTTP requests for the user feature. It uses the `UserService` to perform the business logic and returns the result as a `ResponseEntity`.

```java
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
            return ResponseEntity.status(409).body("email already exists
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
```

## How to Create a New Endpoint

To create a new endpoint, you need to follow these steps:

1.  **Create a DTO** (if necessary) to define the data that will be exchanged with the client.
2.  **Create a method in the Repository** to access the data from the database.
3.  **Create a method in the Service** to implement the business logic.
4.  **Create a method in the Controller** to handle the HTTP request and return the response.

## Running the Application

To run the application, you can use the following command:

```bash
docker-compose up --build -d
```

This will start the application and all the required services (database, Kafka, etc.).

## Running the Tests

To run the tests, you can use the following command:

```bash
./mvnw test
```

This will run all the tests in the project.