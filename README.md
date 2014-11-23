The source code of http://perlmaven.com/
VERSION 0.11

Theoretically this code should be usable to run other sites
as well, but there are two main issues:

1) Probabaly there are number of assumptions specific to the Perl-Maven site.
   (These should be cleaned up, so if you encounter them, open a ticket)

2) The application is in flux. I might make some major changes to the file format
   or the configuration format as I try to make the site more generic. This,
   combined with a lack of test coverage might lead to some frustration.
   Even though if I change the file-format, I'll probably also write a converter
   as I'll need it too.

With that said, you are more than welcome to try the application, give feedback,
suggest bug fixes, features, changes etc.

Setup
==========

clone the Perl-Maven repository ( https://github.com/szabgab/Perl-Maven )
(or fork in and clone the forked version)

```$ git clone https://github.com/szabgab/Perl-Maven.git```

clone the repository of the articles https://github.com/szabgab/perlmaven.com
into a directory next to the Perl-Maven directory

```$ git clone https://github.com/szabgab/perlmaven.com.git```


    somdedir/
        Perl-Maven/
        perlmaven.com/

Generate the meta files:

    $ cd Perl-Maven
    $ perl bin/create_meta.pl --all

Create the database:

    $ perl bin/setup.pl

Configure DNS name resolving of perlmaven.com.local to 127.0.0.1
(On Linux/Unix add the following line to /etc/hosts :

    127.0.0.1 perlmaven.com.local


Launch the application:

    $ perl bin/app.pl

Visit  http://perlmaven.com.local:3000/

You should be able to see the English website.

If you also create DNS mapping for 
127.0.0.1 ko.perlmaven.com.local
Then you can visit http://ko.perlmaven.com.local:3000/
though the links between the language will lead to the production site.


Contribution
===============

Before contributing anything beyond really simple fixes, please open an issue and then
in each commit message mention that issue. That will make it easier later to map changes
to features.


Third-party sources
------------------------

The flags are from  https://www.gosquared.com/resources/flag-icons/
Found them on http://www.iconarchive.com/show/flag-icons-by-gosquared.2.html

Video player:
https://github.com/videojs/video.js/blob/stable/docs/guides/setup.md


Multilingual site
-----------------
The http://perlmaven.com/ site provides multi-lingual capabilities.
The default site on that URL is in English, but there are localized versions
of the site on URLs such as http://br.perlmaven.com/ http://cn.perlmaven.com/
http://he.perlmaven.com/


Adding a new language (site)
-----------------------------
* Get the language code from wikimedia
* Create the sites/CC/ from skeleton
* Add the language to sites.yml
* Add site to the  app.psgi and restart Starman on the server
* Updating the mymaven.yml configuration file is optional


Registration and purchase process
=================================

Register:
  - user types in e-mail
  - system send e-mail with confirmation code
  - when user clicks on link the account is verified,
    the user is marked as logged in and prompted for a password
      (but the system also sais the password can be set later.

  - If a user has not been verified yet, send an e-mail and ask
    if I can help (or shall I just delete the old but unverified
    accounts?
  - If a user does not yet have a password, send an e-mail   
    explaining the new story

