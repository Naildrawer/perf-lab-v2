package com.naildrawer.app.controller;

import com.naildrawer.app.model.User;
import com.naildrawer.app.repository.UserRepository;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.URI;

@RestController
@RequestMapping("/users")
public class UserController {

    private final UserRepository repository;

    public UserController(UserRepository repository) {
        this.repository = repository;
    }

    @Cacheable("users")
    @GetMapping
    public Iterable<User> getUsers() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public ResponseEntity<User> getUser(@PathVariable Long id) {
        return repository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @CacheEvict(value = {"users", "user"}, allEntries = true)
    @PostMapping
    public ResponseEntity<User> create(@RequestBody User user) {
        User savedUser = repository.save(user);
        return ResponseEntity
                .created(URI.create("/users/" + savedUser.getId()))
                .body(savedUser);
    }

    @CacheEvict(value = {"users", "user"}, allEntries = true)
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        if (!repository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }

        repository.deleteById(id);
        return ResponseEntity.noContent().build();
    }

    @CacheEvict(value = {"users", "user"}, allEntries = true)
    @PutMapping("/{id}")
    public ResponseEntity<User> update(@PathVariable Long id, @RequestBody User user) {
        if (!repository.existsById(id)) {
            return ResponseEntity.notFound().build();
        }

        user.setId(id);
        User updatedUser = repository.save(user);
        return ResponseEntity.ok(updatedUser);
    }
}
