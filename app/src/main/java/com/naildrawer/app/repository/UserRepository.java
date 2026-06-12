package com.naildrawer.app.repository;

import com.naildrawer.app.model.User;
import org.springframework.data.repository.CrudRepository;

public interface UserRepository extends CrudRepository<User, Long> {

}
