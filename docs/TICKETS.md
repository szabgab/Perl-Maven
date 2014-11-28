Tickets or Issues
==================

1) Only registered users with verified e-mail address can use it
2) Open a ticket:

   ticket
     id      INTEGER PRIMARY KEY,
     uid     INTEGER,
     summary VARCHAR(255),
     field   [some list of things],
     text    BLOB,
     timestamp,
     who_can_see_it    (public, registered_users, pm_system)
     state   [new, open, waiting_for_more_input, waiting_for_system, closed]

   reply
     id      INTEGER PRIMARY KEY,
     tid     INTEGER,
     uid     INTEGER,
     timestamp,
     text    BLOB




