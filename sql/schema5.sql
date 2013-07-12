ALTER TABLE user ADD COLUMN interest BLOB;

CREATE TABLE interests (
  uid    INTEGER NOT NULL,
  name   VARCHAR(20),
  FOREIGN KEY (uid) REFERENCES user(id)
);

