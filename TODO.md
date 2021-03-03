
+ create_meta handles all the domains at once
+ Integrate the series.yml files needs to be per domain as well
+ Integrate the gabor/config/s12/code-maven/mail/  directory
+ Integrate the ads directory should be served from the templates directory as well
+ Create a forbid-list of domains for email addresses:
+ Purge registrations that are not confirmed and that are more than a week old and that don't have any other products
  than the default products.

  SELECT MAX(id) FROM user;
  SELECT COUNT(*) FROM user WHERE verify_time IS NULL AND id < 10000 AND id NOT IN (SELECT uid FROM subscription);
  DELETE FROM user WHERE verify_time IS NULL AND id < 10000 AND id NOT IN (SELECT uid FROM subscription);
  SELECT * FROM verification WHERE uid NOT IN (SELECT id FROM user) LIMIT 2;

+ Can the cookie_domain that is currently set in environments/deployment.yml be set in the code?
cookie_domain: ".perlmaven.com"
  No, but I switched to Dancer2::Session::Cookie


- the pm.db should be configured from the mymaven.yml file or we should use a single pm.db for multiple domains.
*) add a free product called code_maven to the pm database.
*) See how the GUI behaves 
*) Script that takes one database, and copies the users to the other database and when duplicate users are encountered adding the
   new, code_maven product.
   ../articles/merge_pm.pl

- Convert Angular back to JQuery



