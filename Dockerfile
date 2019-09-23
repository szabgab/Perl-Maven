FROM ubuntu:19.04
RUN echo "Install Ubuntu packages"             && \
    apt-get update                             && \
    apt-get upgrade -y                         && \
    apt-get install -y cpanminus               && \
    apt-get install -y build-essential         && \
    apt-get install -y libdancer2-perl         && \
    apt-get install -y libcarp-always-perl     && \
    apt-get install -y libemail-valid-perl     && \
    apt-get install -y libemail-mime-perl      && \
    apt-get install -y libemail-stuffer-perl   && \
    apt-get install -y libemail-sender-perl


RUN apt-get install -y starman                            && \
    apt-get install -y libtest-most-perl                  && \
    apt-get install -y libdbi-perl                        && \
    apt-get install -y libdaemon-control-perl             && \
    apt-get install -y libdatetime-perl                   && \
    apt-get install -y libdatetime-tiny-perl              && \
    apt-get install -y libdbi-perl                        && \
    apt-get install -y libdbd-sqlite3-perl                && \
    apt-get install -y libfile-homedir-perl               && \
    apt-get install -y libdancer2-plugin-passphrase-perl


# docker build -t perlmaven .
# docker run --rm -it -v$(pwd):/opt perlmaven

