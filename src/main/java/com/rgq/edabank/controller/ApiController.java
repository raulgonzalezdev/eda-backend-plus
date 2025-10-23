package com.rgq.edabank.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class ApiController {

  @GetMapping("/hello")
  public Map<String, Object> hello() {
    return Map.of("ok", true, "service", "eda-backend");
  }
}
