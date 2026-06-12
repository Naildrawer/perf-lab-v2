CREATE TABLE users
(
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100)
);

INSERT INTO users(name,email)
VALUES
('Max','max@mail.ru'),
('Ivan','ivan@mail.ru'),
('Alex','alex@mail.ru');
