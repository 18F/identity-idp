# Use the official Ruby image because the Rails images have been deprecated
FROM ruby:2.5

# Enable https
RUN apt-get update
RUN apt-get install -y apt-transport-https

# Install Postgres client
RUN apt-get install -y --no-install-recommends postgresql-client
RUN rm -rf /var/lib/apt/lists/*

# Install Chrome for capybara
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - 
RUN sh -c 'echo "deb https://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
RUN apt-get update
RUN apt-get install -y google-chrome-stable

# Install Node 12.x
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get install -y nodejs
RUN ln -s ../node/bin/node /usr/local/bin/
RUN ln -s ../node/bin/npm /usr/local/bin/

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install yarn

# Everything happens here from now on   
WORKDIR /upaya

# Simple Gem cache.  Success here creates a new layer in the image.
COPY Gemfile .
COPY Gemfile.lock .
RUN gem install bundler --conservative
RUN bundle install --without deploy production

# Simple npm cache. Success here creates a new layer in the image.
COPY package.json .
COPY yarn.lock .
RUN yarn install --force

# Copy everything else over
COPY . .

# Up to this point we've been root, change to a lower priv. user
RUN groupadd -r appuser
RUN useradd --system --create-home --gid appuser appuser
RUN chown -R appuser.appuser /upaya
USER appuser

EXPOSE 3000
CMD ["rackup", "config.ru", "--host", "0.0.0.0", "--port", "3000"]
