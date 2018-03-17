## Status
[![Build Status](https://travis-ci.org/szabgab/Perl-Maven.png)](https://travis-ci.org/szabgab/Perl-Maven)
[![Coverage Status](https://coveralls.io/repos/github/szabgab/Perl-Maven/badge.svg?branch=master)](https://coveralls.io/github/szabgab/Perl-Maven?branch=master)

The source code of http://perlmaven.com/
VERSION 0.11

Theoretically this code should be usable to run other sites
as well, but there are two main issues:

1) Probably there are number of assumptions specific to the Perl-Maven site.
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

Create the database:

    $ perl bin/setup.pl

Create configuration directory and configuration file:

    $ mkdir config
    $ cp mymaven.yml.skel config/mymaven.yml

Configure DNS name resolving of example.com.local to 127.0.0.1
(On Linux/Unix add the following line to /etc/hosts :

    127.0.0.1 example.com www.example.com de.example.com

This page shows the location of the hosts file on other operating systems, including
various versions of MS Windows
http://en.wikipedia.org/wiki/Hosts_%28file%29


Create the directory for the pages:

   mkdir -p ../example.com/site/en/pages
   mkdir -p ../example.com/site/en/img
   mkdir -p ../example.com/sites/de/pages

Copy images

  cp public/img/*  ../example.com/sites/en/img/

Create ```../example.com/sites/en/img/favicon.ico```

Menu:

   cp resources.yml.skel ../example.com/sites/en/resources.yml


Create ```../example.com/sites.yml``` with the following content:

  en:
    url: http://example.com/
    english: English
    name: English
  de:
    url: http://de.example.com/
    english: German
    name: Deutsch

Create ```../example.com/site/en/pages/index.txt``` with the following content:


  =title Example site
  =timestamp 2013-07-16T00:00:02
  =status show
  =show_date 0
  =author 0
  =archive 0
  =comments_disqus_enable 0
  =show_related 0
  
  <h2>Welcome to your own Perl-Maven based site</h2>




Generate the meta files:

  $ cd Perl-Maven
  $ perl bin/create_meta.pl

Run the application using ```plackup -r```

And visit the main page at ```http://example.com:5000/```




perlmaven.com
------------

clone the repository of the articles https://github.com/szabgab/perlmaven.com
into a directory next to the Perl-Maven directory

```$ git clone https://github.com/szabgab/perlmaven.com.git```


    somdedir/
        Perl-Maven/
        perlmaven.com/

You should be able to see the English website.

If you also create DNS mapping for 
127.0.0.1 ko.perlmaven.com.local
Then you can visit http://ko.perlmaven.com.local:3000/
though the links between the language will lead to the production site.


Contribution
===============


To tidy the Perl code, run:

```
tidyall -a --refresh-cache
```


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


Munin integration
===================

1) Install the following packages to the system perl  libdbi-perl libdbd-sqlite3-perl libdbd-sqlite-perl libjson-xs-perl libmongodb-perl
2)

```
sudo ln -s /home/foobar/work/Perl-Maven/etc/munin/perl_maven_subscribers_per_product  /etc/munin/plugins/
sudo ln -s /home/foobar/work/Perl-Maven/etc/munin/perl_maven_users  /etc/munin/plugins/
sudo ln -s /home/foobar/work/Perl-Maven/etc/munin/perl_maven_new_users  /etc/munin/plugins/
sudo ln -s /home/foobar/work/Perl-Maven/etc/munin/perl_maven_logs  /etc/munin/plugins/perl_maven_logs_hostnames
sudo ln -s /home/foobar/work/Perl-Maven/etc/munin/perl_maven_logs  /etc/munin/plugins/perl_maven_logs_hostnames_daily
sudo ln -s /home/foobar/work/Perl-Maven/etc/munin/perl_maven_logs  /etc/munin/plugins/perl_maven_logs_translations_daily
sudo ln -s /home/foobar/work/Perl-Maven/etc/munin/perl_maven_logs  /etc/munin/plugins/perl_maven_logs_processing
sudo ln -s /home/foobar/work/Perl-Maven/etc/munin/perl_maven_logs  /etc/munin/plugins/perl_maven_logs_time
sudo ln -s /home/foobar/work/Perl-Maven/etc/munin/perl_maven_mongo  /etc/munin/plugins/perl_maven_mongo_hits
sudo ln -s /home/foobar/work/Perl-Maven/etc/munin/perl_maven_mongo  /etc/munin/plugins/perl_maven_mongo_elapsed_time
```

Add to crontab something like this (except of the username, and the path to perl):

```
*/5 * * * * (cd /home/foobar/work/Perl-Maven/; /home/foobar/dwimperl-linux-5.20.1-10-x86_64/perl/bin/perl etc/munin/perl_maven_logs collect)
```

3) Restart the munin node(!)
```sudo service munin-node restart```


