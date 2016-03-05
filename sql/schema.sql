CREATE TABLE user (
  id              INTEGER PRIMARY KEY,
  email           VARCHAR(255) UNIQUE NOT NULL,
  password        VARCHAR(255),
  password_reset_code VARCHAR(20),
  password_reset_timeout VARCHAR(11),
  register_time   VARCHAR(11),
  verify_code     VARCHAR(20),
  verify_time     VARCHAR(11),
  name            VARCHAR(255),
  admin           INTEGER,
  login_whitelist INTEGER
);

CREATE TABLE product (
  id              INTEGER PRIMARY KEY,
  code            VARCHAR(255) UNIQUE NOT NULL,
  name            VARCHAR(255) UNIQUE NOT NULL,
  price           NUMERIC
);

CREATE TABLE subscription (
  uid    INTEGER NOT NULL,
  pid    INTEGER NOT NULL,
  FOREIGN KEY (uid) REFERENCES user(id),
  FOREIGN KEY (pid) REFERENCES product(id),
  CONSTRAINT uid_pid UNIQUE (uid, pid)
);

CREATE TABLE transactions (
  id     VARCHAR(100) UNIQUE NOT NULL,
  sys    VARCHAR(10),
  ts     VARCHAR(10) NOT NULL,
  data   BLOB
);

CREATE TABLE login_whitelist (
  id      INTEGER PRIMARY KEY,
  uid     INTEGER NOT NULL,
  ip      VARCHAR(40),
  mask    VARCHAR(40),
  note    VARCHAR(100)
);
-- ALTER TABLE user ADD login_whitelist INTEGER;


CREATE TABLE verification (
  code        VARCHAR(100) PRIMARY KEY,
  timestamp   VARCHAR(100) NOT NULL,
  action      VARCHAR(100) NOT NULL,
  uid         INTEGER NOT NULL,
  details     BLOB
);

CREATE TRIGGER user_cleanup
  BEFORE DELETE ON user FOR EACH ROW
  BEGIN
   DELETE FROM subscription WHERE uid=OLD.id;
   DELETE FROM verification WHERE uid=OLD.id;
   DELETE FROM login_whitelist WHERE uid=OLD.id;
  END;



