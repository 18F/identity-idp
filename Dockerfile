FROM rails:4.2.6

RUN echo "deb http://us.archive.ubuntu.com/ubuntu precise main universe" | tee -a /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y libxmlsec1-dev

# For browserify we need node
# TOOD(sbc): Create a separate production container without this.
RUN mkdir /usr/local/node && curl -L https://nodejs.org/dist/v4.4.3/node-v4.4.3-linux-x64.tar.xz | tar Jx -C /usr/local/node --strip-components=1
RUN ln -s ../node/bin/node /usr/local/bin/
RUN ln -s ../node/bin/npm /usr/local/bin/

# For running tests we need phantomjs
# TOOD(sbc): Create a separate production container without this.
RUN mkdir /usr/local/phantomjs && curl -L https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 | tar -xj -C /usr/local/phantomjs --strip-components=1
RUN ln -s ../phantomjs/bin/phantomjs /usr/local/bin/

WORKDIR /upaya

COPY package.json /upaya
RUN npm install

COPY Gemfile /upaya
COPY Gemfile.lock /upaya
RUN gem install bundler
RUN bundler install --without deployment deploy

COPY . /upaya

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
