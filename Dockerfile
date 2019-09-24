FROM ubuntu:19.04
RUN echo "Install Ubuntu packages"                        && \
    apt-get update                                        && \
    apt-get upgrade -y                                    && \
    apt-get install -y cpanminus                          && \
    apt-get install -y build-essential                    && \
    apt-get install -y libdancer2-perl                    && \
    apt-get install -y libcarp-always-perl                && \
    apt-get install -y libemail-valid-perl                && \
    apt-get install -y libemail-mime-perl                 && \
    apt-get install -y libemail-stuffer-perl              && \
    apt-get install -y libemail-sender-perl               && \
    apt-get install -y starman                            && \
    apt-get install -y libtest-most-perl                  && \
    apt-get install -y libdbi-perl                        && \
    apt-get install -y libdaemon-control-perl             && \
    apt-get install -y libdatetime-perl                   && \
    apt-get install -y libdatetime-tiny-perl              && \
    apt-get install -y libdbi-perl                        && \
    apt-get install -y libdbd-sqlite3-perl                && \
    apt-get install -y libfile-homedir-perl               && \
    apt-get install -y libdancer2-plugin-passphrase-perl  && \
    apt-get install -y ack                                && \
    apt-get install -y htop                               && \
    apt-get install -y libtest-www-mechanize-psgi-perl    && \
    apt-get install -y libtest-script-perl                && \
    apt-get install -y libsvg-perl                        && \
    apt-get install -y libnet-twitter-perl                && \
    apt-get install -y libmoox-options-perl               && \
    apt-get install -y libarchive-any-perl                && \
    apt-get install -y libmongodb-perl                    && \
    apt-get install -y libdbix-runsql-perl                && \
    apt-get install -y libdata-structure-util-perl        && \
    apt-get install -y libmetacpan-client-perl            && \
    apt-get install -y libperl-prereqscanner-perl         && \
    apt-get install -y libjson-xs-perl                    && \
    apt-get install -y libcpanel-json-xs-perl             && \
    apt-get install -y libjson-perl                       && \
    # needed by Code::Explain
    apt-get install -y libtest-nowarnings-perl            && \
    # needed by Dancer2::Session::Cookie
    apt-get install -y libtest-mockobject-perl            && \
    # needed by Dancer2::Session::Cookie
    apt-get install -y libsession-storage-secure-perl     && \
    # needed by EBook::MOBI
    apt-get install -y libtext-trim-perl                  && \
    # needed by EBook::MOBI
    apt-get install -y libimage-size-perl                 && \
    # needed by Module::Version
    apt-get install -y libtest-output-perl                && \
    # needed by URL::Encode::XS
    apt-get install -y liburl-encode-perl                 && \
    echo "DONE"

RUN echo "Install more Perl Modules" && \
    cpanm --notest Business::PayPal  && \
    cpanm Code::Explain              && \
    cpanm Web::Feed                  && \
    cpanm Dancer2::Session::Cookie   && \
    cpanm EBook::MOBI                && \
    cpanm Module::Version            && \
    cpanm URL::Encode::XS            && \
    echo "DONE"

RUN echo "Needed for testing"                   && \
    apt-get install -y libtest-version-perl     && \
    apt-get install -y libtest-perl-critic-perl && \
    apt-get install -y libcode-tidyall-perl     && \
    cpanm Perl::Tidy                            && \
    echo "DONE"

WORKDIR /opt


# docker build -t perlmaven .
# docker run --rm -it -v$(pwd):/opt perlmaven

