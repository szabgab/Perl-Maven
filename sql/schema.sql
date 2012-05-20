CREATE TABLE user (
  id              INTEGER PRIMARY KEY,
  email           VARCHAR(255) UNIQUE NOT NULL,
  password        VARCHAR(255),
  password_reset_code VARCHAR(20),
  password_reset_timeout VARCHAR(11),
  register_time   VARCHAR(11),
  verify_code     VARCHAR(20),
  verify_time     VARCHAR(11)
);
