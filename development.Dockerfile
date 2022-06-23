# Use build image first for heavy lifting
FROM logindotgov/build as build

# Everything happens here from now on
WORKDIR /idp

# Set MAKEFLAGS to scale with compute capacity
ENV MAKEFLAGS "-j$(nproc)"

# Install dev and test gems
COPY Gemfile Gemfile.lock ./
RUN bundle install -j $(nproc) --system --with development test

# Install NPM packages
COPY package.json yarn.lock ./
RUN NODE_ENV=development yarn install --force \
    && yarn cache clean

# Switch to base image and add in Gems
FROM logindotgov/build
WORKDIR /idp

# Copy system Gems into base container
COPY --from=build /usr/local/bundle /usr/local/bundle

# Set alternate node module path and copy NPMs in - Avoids conflict
# with local node_modules for dev
ENV NODE_PATH=/usr/local/node_modules
COPY --from=build /idp/node_modules /usr/local/node_modules

# Install Chrome for integration tests
RUN curl -sS https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && sh -c 'echo "deb https://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Copy in whole source (minus items matched in .dockerignore)
COPY --chown=appuser:appuser . .

# Up to this point we've been root, change to a lower priv. user
USER appuser

EXPOSE 3000
CMD ["bundle", "exec", "rackup", "config.ru", "--host", "0.0.0.0", "--port", "3000"]
