CREATE TABLE IF NOT EXISTS users
(
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100)
);

INSERT INTO users(name, email)
SELECT 'Max', 'max@mail.ru'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'max@mail.ru');

INSERT INTO users(name, email)
SELECT 'Ivan', 'ivan@mail.ru'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'ivan@mail.ru');

INSERT INTO users(name, email)
SELECT 'Alex', 'alex@mail.ru'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE email = 'alex@mail.ru');
