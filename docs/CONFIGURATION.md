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

  
