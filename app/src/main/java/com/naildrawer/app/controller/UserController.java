
package com.naildrawer.app.controller;

import com.naildrawer.app.model.User;
import com.naildrawer.app.repository.UserRepository;

import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.web.bind.annotation.*;

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

    @Cacheable(value = "user", key = "#id")
    @GetMapping("/{id}")
    public User getUser(@PathVariable Long id) {
        return repository.findById(id).orElse(null);
    }

    @CacheEvict(value = {"users", "user"}, allEntries = true)
    @PostMapping
    public User create(@RequestBody User user) {
        return repository.save(user);
    }

    @CacheEvict(value = {"users", "user"}, allEntries = true)
    @DeleteMapping("/{id}")
    public void delete(@PathVariable Long id) {
        repository.deleteById(id);
    }

    @CacheEvict(value = {"users", "user"}, allEntries = true)
    @PutMapping("/{id}")
    public User update(@PathVariable Long id, @RequestBody User user) {
        user.setId(id);
        return repository.save(user);
    }
}
