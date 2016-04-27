FROM rails:4.2.6

WORKDIR /upaya

COPY Gemfile /upaya
COPY Gemfile.lock /upaya
RUN bundler install --without deployment deploy

# This container supports running tests and as such requires the phantomjs
# binary in the PATH.
# TOOD(sbc): Create a separate production container without this.
RUN mkdir /usr/local/phantomjs && curl -L https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 | tar jx -C /usr/local/phantomjs --strip-components=1
RUN ln -s ../phantomjs/bin/phantomjs /usr/local/bin/phantomjs

COPY . /upaya

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
