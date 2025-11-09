# Contribuyendo a EDA Backend Plus

## Navegación
- Inicio: [README](../README.md)
- Metodología: [Metodologia.md](Metodologia.md)
- Observabilidad (APM/OTel): [observability-overview.md](observability-overview.md)
- Resiliencia BD (Patroni + HAProxy): [database-resilience.md](database-resilience.md)
- Balanceador NGINX: [README-LoadBalancer.md](README-LoadBalancer.md)
- Guía de entrevista: [guia-entrevista-backend.md](guia-entrevista-backend.md)
- Contribución (ES): [CONTRIBUTING.es.md](CONTRIBUTING.es.md)
- Contribución (EN): [CONTRIBUTING.md](CONTRIBUTING.md)
- Esquema POS y DDL: [pos_schema_instructions.md](pos_schema_instructions.md)
- OpenAPI: [../specs/openapi.yaml](../specs/openapi.yaml) · AsyncAPI: [../specs/asyncapi.yaml](../specs/asyncapi.yaml)

En primer lugar, ¡gracias por considerar contribuir a este proyecto! Son personas como tú las que hacen de este proyecto una gran herramienta.

Este documento proporciona una guía para que los desarrolladores contribuyan a este proyecto. Describe el patrón arquitectónico, la estructura de una característica y el proceso para crear un nuevo punto final.

## Patrón Arquitectónico

Este proyecto sigue un patrón de arquitectura en capas clásico, que es común en las aplicaciones de Spring Boot. Las capas son:

- **Controlador (Controller)**: Esta capa es responsable de manejar las solicitudes HTTP entrantes, validar la entrada y devolver una respuesta HTTP adecuada. Utiliza DTO (Objetos de Transferencia de Datos) para comunicarse con el cliente.
- **Servicio (Service)**: Esta capa contiene la lógica de negocio de la aplicación. Coordina la interacción entre las capas de controlador y repositorio.
- **Repositorio (Repository)**: Esta capa es responsable del acceso a los datos. Interactúa con la base de datos para realizar operaciones CRUD (Crear, Leer, Actualizar, Eliminar).
- **Modelo (Model)**: Esta capa representa el modelo de datos de la aplicación. Es un objeto Java simple que se asigna a una tabla de la base de datos.
- **DTO (Data Transfer Object)**: Esta capa se utiliza para transferir datos entre el controlador y el cliente. Ayuda a desacoplar el modelo de datos interno de la API que se expone al cliente.

## Estructura de una Característica (Ejemplo de CRUD de Usuario)

Para ilustrar la estructura de una característica, tomemos el ejemplo de una característica de CRUD (Crear, Leer, Actualizar, Eliminar) de Usuario.

### 1. Modelo (`User.java`)

El modelo `User` representa a un usuario en el sistema. Es una entidad JPA que se asigna a la tabla `users` en la base de datos.

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

El `UserDto` se utiliza para transferir datos de usuario entre el cliente y el servidor. No incluye el `hashedPassword` por razones de seguridad.

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

### 3. Repositorio (`UserRepository.java`)

El `UserRepository` proporciona los métodos para interactuar con la tabla `users` en la base de datos. Extiende `JpaRepository`, que proporciona las operaciones CRUD básicas.

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

### 4. Servicio (`UserService.java`)

El `UserService` contiene la lógica de negocio para la característica del usuario. Utiliza el `UserRepository` para interactuar con la base de datos.

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

### 5. Controlador (`UserController.java`)

El `UserController` maneja las solicitudes HTTP para la característica del usuario. Utiliza el `UserService` para realizar la lógica de negocio y devuelve el resultado como un `ResponseEntity`.

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
```

## Cómo Crear un Nuevo Punto Final

Para crear un nuevo punto final, sigue estos pasos:

1.  **Define el DTO**: Si el punto final requiere un cuerpo de solicitud o devuelve un cuerpo de respuesta, define un DTO para ello.
2.  **Crea el método del Repositorio**: Si el punto final requiere una consulta a la base de datos que no está cubierta por los métodos básicos de CRUD, crea un nuevo método en el repositorio.
3.  **Crea el método del Servicio**: Crea un nuevo método en el servicio que contenga la lógica de negocio para el punto final.
4.  **Crea el método del Controlador**: Crea un nuevo método en el controlador que maneje la solicitud HTTP y llame al método del servicio.

## Cómo Ejecutar la Aplicación

Para ejecutar la aplicación, puedes usar el siguiente comando de Docker Compose:

```bash
docker-compose up -d --build
```

## Cómo Ejecutar las Pruebas

Para ejecutar las pruebas, puedes usar el siguiente comando de Maven:

```bash
mvn test
```

---

Navegación rápida: [Volver al README](../README.md) · [Índice de docs](index.md) · [Mapa del proyecto](project-map.md) · [Guía de entrevista](guia-entrevista-backend.md) · [Observabilidad](observability-overview.md)