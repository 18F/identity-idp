# Use the official Ruby image because the Rails images have been deprecated
FROM ruby:2.5

# Install packages of https
RUN apt-get update
RUN apt-get install -y apt-transport-https
RUN apt-get install -y --no-install-recommends postgresql-client
RUN rm -rf /var/lib/apt/lists/*

# Install Node 12.x
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get install -y nodejs
RUN ln -s ../node/bin/node /usr/local/bin/
RUN ln -s ../node/bin/npm /usr/local/bin/

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install yarn

# RUN mkdir /upaya
WORKDIR /upaya

# Simple Gem cache.  Success here creates a new layer in the image.
COPY Gemfile /upaya
COPY Gemfile.lock /upaya
RUN gem install bundler --conservative
RUN bundle check || bundle install --without deploy production

# Simple npm cache. Success here creates a new layer in the image.
COPY package.json /upaya
COPY yarn.lock /upaya
RUN yarn install

# Copy everything else over
COPY . /upaya

# Up to this point we've been root, change to a lower priv. user
RUN groupadd -r appuser
RUN useradd --system --gid appuser appuser
RUN chown -R appuser.appuser /upaya
USER appuser

EXPOSE 3000
CMD ["rackup", "config.ru", "--host", "0.0.0.0", "--port", "3000"]
