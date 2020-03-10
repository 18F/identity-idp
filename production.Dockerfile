# Use the official Ruby image because the Rails images have been deprecated
FROM ruby:2.5-slim

# Set necessary ENV
ENV LC_ALL=C.UTF-8

# Enable package fetch over https and add a few core tools
RUN apt-get update \
    && apt-get install -y \
       apt-transport-https \
       curl \
    && rm -rf /var/lib/apt/lists/*

# Install Postgres client
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       postgresql-client \
       libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node 12.x
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s ../node/bin/node /usr/local/bin/ \
    && ln -s ../node/bin/npm /usr/local/bin/

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install yarn \
    && rm -rf /var/lib/apt/lists/*

# Everything happens here from now on   
WORKDIR /upaya

# Simple Gem cache.  Success here creates a new layer in the image.
# Note - Installs build related debs then removes after use
COPY Gemfile Gemfile.lock ./
RUN apt-get update \
    && apt-get install -y \
       build-essential \
       git \
       liblzma-dev \
       patch \
       ruby-dev \
    && gem install bundler --conservative \
    && bundle install --deployment --without development test \
    && apt-get remove -y \
       build-essential \
       git \
       liblzma-dev \
       patch \
       ruby-dev \
    && apt autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Simple npm cache. Success here creates a new layer in the image.
COPY package.json yarn.lock ./
RUN NODE_ENV=development yarn install --force

# Copy in whole source (minus items matched in .dockerignore)
COPY . .

# Add application user and fix perms
RUN groupadd -r appuser \
    && useradd --system --create-home --gid appuser appuser \
    && chown -R appuser.appuser /upaya

# Up to this point we've been root, change to a lower priv. user
USER appuser

EXPOSE 3000
CMD ["bundle", "exec", "rackup", "config.ru", "--host", "0.0.0.0", "--port", "3000"]
