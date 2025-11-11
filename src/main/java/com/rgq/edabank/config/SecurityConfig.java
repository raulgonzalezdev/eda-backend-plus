package com.rgq.edabank.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.configuration.WebSecurityCustomizer;
import org.springframework.security.web.util.matcher.AntPathRequestMatcher;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.http.HttpMethod;
import org.springframework.boot.autoconfigure.security.servlet.PathRequest;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;

@Configuration
public class SecurityConfig {

  @Value("${app.jwt.secret:dev-super-secret-change-me}")
  private String jwtSecret;

  @Bean
  SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    http
      .csrf(csrf -> csrf.disable())
      .authorizeHttpRequests(auth -> auth
        // Recursos estáticos comunes (css, js, images, webjars)
        .requestMatchers(PathRequest.toStaticResources().atCommonLocations()).permitAll()
        // Páginas estáticas específicas
        .requestMatchers(HttpMethod.GET, "/", "/index.html", "/chat-test.html").permitAll()
        // Handshake de WebSocket/SockJS
        .requestMatchers("/ws/**").permitAll()
        // Endpoints públicos existentes
        .requestMatchers("/auth/**", "/api/health", "/actuator/health", "/v3/api-docs", "/swagger-ui/**", "/swagger-ui.html").permitAll()
        .anyRequest().authenticated()
      )
      .oauth2ResourceServer(oauth -> oauth.jwt(Customizer.withDefaults()));
    return http.build();
  }

  @Bean
  JwtDecoder jwtDecoder() {
    SecretKey key = new SecretKeySpec(jwtSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    return NimbusJwtDecoder.withSecretKey(key).build();
  }

  @Bean
  public WebSecurityCustomizer webSecurityCustomizer() {
  // Not using web.ignoring(); endpoints are permitted via HttpSecurity
  return (web) -> {
  };
  }
}
