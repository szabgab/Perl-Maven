The format of the articles has evolved from POD, HTML and Docbook. It is now a mess. I know. I'll have to clean that up.

Nevertheless the overview:

In the header there are

```
    =key value
```

pairs of meta information.

Header values:

```
    =title Is the title of the article

    =timestamp 2015-02-01T07:30:01

       The time when the article is published. In that exact format.

    =author szabgab
      The nickname of the author of the article
      The nicknames are listed in the authors.txt file.

    =status draft|done|show

    =description
       Option field of text that will be used as the meta description tag in the HTML header.

    =indexes
       Optional comma separated list of keywords that are indexed and made searchable

    =tags ???

    =mp3 ??

    =original
      Optional flag relevant to the translated articles. The value should be the filename of the original English article.
      This is the key that is used to connect the translations of a single article. Each translation points to its original.

    =books some_key
        Optional comma separated list.
        These are not really books any more, but groups of articles such as 'moo', or 'dancer' or 'beginner'

    =translator
      The nickname of the person who transleted this article. (Only relevant to the translations themselves.)
      The nicknames are listed in the authors.txt file.

    =redirect
      An optional URL (http://...  or just /path) where visitors to this page should be redirect.
      We use this mode of redirection if we would like to keep the original text as well (at least the headers and the abstract)
      So they can be still displayed in the arcchive.


    Flags that can be either 1 =  true or 0 = false
    There are a bunch of these flags set on the level of the whole perlmaven site, that can be overridenn on the specific sub-site level,
    that can be overridden by the individual pages using the header flags:

    =archive 1
        Boolean.  Should the page be listed on the /archive  page?

    =comments_disqus_enable 1
        Boolean. Enable/Disable commands using Disqus

    =show_social
        Boolean. Shall we show the social widgets (Twitter, Reddit, Facebook, G+)

    =show_newsletter_form
    =show_right
    =show_related
    =show_date
    =show_ads
```

lib/Perl/Maven/Page.pm has the full list of header values. Both those that are inherited from the mymaven configuration and those
that can only appear in the headr of an article.


The text between

```
    =abstract start

    =abstract end
```

is displayed on the front pages and is included in the RSS/Atom feed.


`<h2>` is used for internal titles.

`<hl></hl>` stands for highlight and usually code-snippets inside the text are marked with these.

`<b></b>` is used to mark other important pieces.


Code snippets and full Examples
--------------------------------

Code snippets can be included in the body of the article,
within these tags. It is better not to leave empty rows at the beginning
and the end of the examples.

    <code lang="perl">
    </code>

Full-blown examples (including use strict, use warnings etc.) can be added
in separate files in the examples/ subdirectory.
and then they can be included using this:

   <include file="examples/filename.pl">

creating a subdirectory for an example that consists of several files is a good idea.
If there are multiple versions of the file then it is better to
create directories and put the file in those directories like this:

   article_name/
        version_1/
              script.pl
              lib/MyModule.pm
        version_2/
              script.pl
              lib/MyModule.pm

even if some of the files need to be duplicated.

HTML examples (mostly on Code-Maven.com) can also use the

   <try file="examples/filename.pl">




Separate controls to include files in the following places:

    =status show   is required for each one of the following

    /   (homepage)     (uses the 'archive' meta file)
    /archive           (uses the 'archive' meta file)
    /category/     ??  (uses the 'categories' and 'archive' meta files)
    /atom              (uses the 'archive' meta file)
    /keywords and /search  (using the 'keywords' meta file)
    /sitemap.xml       (uses the 'sitemap' meta file)

```
/slides - generated separately
/category - based on the =books tag in each file.
=tags
=indexes - these values are displayed at the top of the page as blue buttons.
```

In each language there can be a file called `series.yml` (e.g.  `sites/LANG/series.yml`)
that contains lists of pages in "pages-serieses". Based on this we have the list of page on the left.

