package com.naildrawer.app.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class GreetingController {

    @GetMapping("/instance")
    public String instance() {
        String hostname = System.getenv("HOSTNAME");
        return hostname != null ? hostname : "unknown";
    }

    @GetMapping("/hello")
    public String hello() {
        return "Hello Performance Engineer!";
    }

}
