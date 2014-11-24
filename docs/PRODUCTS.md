Description of the products and the buying of products (and services).
=====================================================================


Product types
--------------

Eevery product can have a list of items
  - downloadable files (pdf, zip, tar.gz)
  - web pages (e.g. articles)
  - videos (mp4, webm, etc. files) these can be downloaded, played on an html page.
With time we might replace some of the files in a product by other files. For example when we release a new edition of an e-book
we might want to give it a name based on the version number.
An item can be part of more than one products. For example we can have a product called "Learn PSGI" and a product "Learn Dancer"
and both can have items covering "Introduction to Template Toolkit".
An item can be a given file /download/frobnix/frobo-1.23.tar.gz  (+ title)


product: id, code, name, price  (TODO: currency), type: unlimited, recurring



Each product can be sold for a fixed price.
There can be a discount for a single product (product_id, dicount_code, price, end date)

There can be a discount ????





1) One-time payment
   paied -> enable
   Refund payment -> disable

2) Subscription:
     payment arrives on date covering a period => enable and set expiration date on the product
     cancelled => does not need to do anything, the exparation date will take care of it
     refund => disable
     'Payment Skipped' ??
3) Subscription with some free period
     When the user signs up to the service, we enable and set an expiration date
     cancelled => we can either cancel the subscription or we can let it expire
     The rest is the same as in 2)
4) Giving free subscription to someone
    Set an expiration date
    Be also able to allow 'no expiration date'

On a regular base we run a script that checks for expired services and removes them from the user.
If someone tries to sign up to a service that was expired we can let the user do this.
I think the only loophole might be people signing up to free subscription, cancelling it and then signing up again.
This is not a big issue for us, but we could save a flag that says, 'this user has already had a free period'
and then not let the free signup. I don't think this is worth the effort now.

Daily cron job that will check all the subscriptions and send e-mail to the ones that will be charged in the next 24 hours.
(or some other time period)
It will also remove subscriptions that have expired a while ago. (e.g. a week ago)



If the user is already logged in to Perl Maven
-----------------------------------------------

When viewing a page (eg. /pro ) we have a button that will lead to the /buy url.
When user arrives to the /buy URL shows the paypal button and saves a unique value for this potential
transaction.

When we get an IPN message we need to check what kind of message is that.




If the user is not logged in
----------------------------

or now we require the user to be logged in when starting the transaction,
ut later we should implement a version when the user can start withot being logged in.
hen the question will be: shall we create a new account with the e-mail received from PayPal
  or shall we look for the account of the user.
If the e-mail supplied by Paypal is in our database already
   assume they are the same user and add the purchase to that account
   and even log the user in (how?)
If the e-mail exists but not yet verified in the system ????
If this is a new e-mail, save the data as a new user and
at the end of the transaction ask the user if he already
has an account or if a new one should be created?
If the user wants to use the existing account, ask for credentials,
after successful login merge the two accounts



