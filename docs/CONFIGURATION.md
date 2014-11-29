The main configuration file is called mymaven.yml

For a multi-language installation we can have configuration option set 
  1) for the whole installation under the 'installation' key
  2) Each sudomain can ovverride these configuration values inside the
     'installation -> sites -> subdomain.name' key
  3) Some configuration option should be overridable by each page as well
     For example 'enable_comments' shuld be overridable, but 'google_analytics' probably not.
     For now, I think we do not need to handle this distinction, and we can allow the page to override both.


For example

installation:
  # here come the generic configuration options
  sites:
    fr.domain.com
      # here come the configurations of fr.domain.com
    domain.com
      # here come the configuration of domain.com

 

Commenting
-----------

We can enable/disable commenting on the site and on the subdomain level using the
'conf.enable_comments'

The value of this field can be either 0 or 'disqus';

Currently we have integration with Disqus.

If commenting is enabled for the whole subdomain, individual pages can enable/disable commenting using the =comment flag.
The `conf.disqus` option provides the disqus code to be used on a specifc subdomain.


In the future we will provide built-in commenting. I am not sure when that happens if we should still allow the integration of
Disqus and maybe other commenting systems as well? Maybe someone will want to enable multiple commenting systesm.
In-house, Disqus, Facebook, G+... so probbaly we should allow each one separately.
So we probbaly want:

conf.comments_internal_enable: 0/1

conf.comments_disqus_enable: 0/1
conf.comments_disqus_code: 'code'

conf.comments_facebook_enable: 0/1
...

and then in the actual page we will have
=comments_disqus_enable: 1

Once there is an internal commenting system, we might want to 
  on new pages enable internal, disable disqus
  on old pages we might want to show disqus but make it read-only.
    that might need a separate configuration option.

There might be extra configuration options.

