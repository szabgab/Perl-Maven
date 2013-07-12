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

CREATE TRIGGER user_cleanup
  BEFORE DELETE ON user FOR EACH ROW
  BEGIN
   DELETE FROM subscription WHERE uid=OLD.id;
  END;

INSERT INTO product (id, code, name, price) VALUES (2, 'beginner_perl_maven_ebook', 'Beginner Perl Maven e-book', 0.01);
INSERT INTO product (code, name, price) VALUES ('perl_maven_cookbook', 'Perl Maven Cookbook', 39);

