package com.rgq.edabank.controller;

import com.nimbusds.jose.*;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Date;
import java.util.UUID;

@RestController
public class AuthController {
  @Value("${app.jwt.secret:dev-super-secret-change-me}")
  private String jwtSecret;

  @GetMapping("/auth/token")
  public ResponseEntity<?> token(@RequestParam(defaultValue = "demo-user") String sub,
                                 @RequestParam(defaultValue = "alerts.read") String scope) throws Exception {
    JWSSigner signer = new MACSigner(jwtSecret.getBytes());
    Instant now = Instant.now();
    JWTClaimsSet claims = new JWTClaimsSet.Builder()
        .subject(sub)
        .issuer("demo-issuer")
        .claim("scope", scope)
        .jwtID(UUID.randomUUID().toString())
        .issueTime(Date.from(now))
        .expirationTime(Date.from(now.plusSeconds(3600)))
        .build();
    JWSHeader header = new JWSHeader.Builder(JWSAlgorithm.HS256).type(JOSEObjectType.JWT).build();
    SignedJWT jwt = new SignedJWT(header, claims);
    jwt.sign(new MACSigner(jwtSecret.getBytes()));
    return ResponseEntity.ok(jwt.serialize());
  }
}
