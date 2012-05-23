CREATE TABLE product (
  id              INTEGER PRIMARY KEY,
  code            VARCHAR(255) UNIQUE NOT NULL,
  name            VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE subscription (
  uid    INTEGER NOT NULL,
  pid    INTEGER NOT NULL,
  FOREIGN KEY (uid) REFERENCES user(id),
  FOREIGN KEY (pid) REFERENCES product(id),
  CONSTRAINT uid_pid UNIQUE (uid, pid)
);

