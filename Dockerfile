# Use the official Ruby image because the Rails images have been deprecated
FROM ruby:2.3

# Install packages of https
RUN apt-get update && apt-get install apt-transport-https

# npm and yarn is needed by webpacker to install packages
# TOOD(sbc): Create a separate production container without this.
RUN mkdir /usr/local/node \
    && curl -L https://nodejs.org/dist/v8.9.4/node-v8.9.4-linux-x64.tar.xz | tar Jx -C /usr/local/node --strip-components=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s ../node/bin/node /usr/local/bin/
RUN ln -s ../node/bin/npm /usr/local/bin/
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
  && apt-get update && apt-get install yarn

# PhantomJS is required for running tests
# TOOD(sbc): Create a separate production container without this.
ENV PHANTOMJS_SHA256 86dd9a4bf4aee45f1a84c9f61cf1947c1d6dce9b9e8d2a907105da7852460d2f

RUN mkdir /usr/local/phantomjs \
    && curl -o phantomjs.tar.bz2 -L https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 \
    && echo "$PHANTOMJS_SHA256 *phantomjs.tar.bz2" | sha256sum -c - \
    && tar -xjf phantomjs.tar.bz2 -C /usr/local/phantomjs --strip-components=1 \
    && rm phantomjs.tar.bz2

RUN ln -s ../phantomjs/bin/phantomjs /usr/local/bin/

WORKDIR /upaya

COPY package.json /upaya

COPY Gemfile /upaya
COPY Gemfile.lock /upaya

RUN gem install bundler --conservative
RUN bundle check || bundle install --without deploy production

COPY . /upaya

EXPOSE 3000
CMD ["rackup", "config.ru", "--host", "0.0.0.0", "--port", "3000"]
