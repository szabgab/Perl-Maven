CREATE TABLE transactions (
  id     VARCHAR(100) UNIQUE NOT NULL,
  sys    VARCHAR(10),
  ts     VARCHAR(10) NOT NULL,
  data   BLOB 
);
ALTER TABLE product ADD COLUMN price NUMERIC;
UPDATE product SET price = 0 WHERE id = 1;
INSERT INTO product (id, code, name, price) VALUES (2, 'beginner_perl_maven_ebook', 'Beginner Perl Maven e-book', 0.01);

