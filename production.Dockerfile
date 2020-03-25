# Use build to install our required Gems
FROM identity-rails_build as build

# Everything happens here from now on   
WORKDIR /upaya

# Prod Gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --deployment --clean --without development test

# Prod NPM packages
COPY package.json yarn.lock ./
RUN NODE_ENV=development yarn install --force \
    && yarn cache clean

# Switch to base image
FROM identity-rails_base
WORKDIR /upaya

# Copy Gems, NPMs, and other relevant items from build layer
COPY --chown=appuser:appuser --from=build /upaya .

# Copy in whole source (minus items matched in .dockerignore)
COPY --chown=appuser:appuser . .

# Up to this point we've been root, change to a lower priv. user
USER appuser

EXPOSE 3000
CMD ["bundle", "exec", "rackup", "config.ru", "--host", "0.0.0.0", "--port", "3000"]
