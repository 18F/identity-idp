# Grab install from node image
FROM node:16.20.0 AS node
# Use the official Ruby image as the base
FROM ruby:3.2.2 AS ruby
# Use Ubuntu 20.04 as the base image
FROM ubuntu:20.04

# Set environment variables
ENV RAILS_ROOT /app
ENV RAILS_ENV production
ENV NODE_ENV production
ENV RAILS_SERVE_STATIC_FILES true
ENV RAILS_LOG_TO_STDOUT true
ENV LOGIN_CONFIG_FILE $RAILS_ROOT/tmp/application.yml
ENV RAILS_LOG_LEVEL debug
ENV BUNDLE_PATH /usr/local/bundle
ENV PATH="/app/bin:${PATH}"
ENV YARN_VERSION=1.22.5

# Create a new user and set up the working directory
RUN addgroup --gid 1000 app && \
    adduser --uid 1000 --gid 1000 --disabled-password --gecos "" app && \
    mkdir -p $RAILS_ROOT && \
    chown -R app:app $RAILS_ROOT

# Setup timezone data
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libpq-dev \
    libssl-dev \
    libyaml-dev \
    postgresql-client \
    tzdata \
    openssl

# Install yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn-archive-keyring.gpg >/dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y yarn=1.22.5-1

# Copy Ruby installation from ruby image
COPY --from=ruby /usr/local/ /usr/local/

# Copy Node.js installation from node image
COPY --from=node /usr/local /usr/local

# Create the working directory
RUN mkdir -p $RAILS_ROOT
WORKDIR $RAILS_ROOT

# Add the application code
COPY --chown=app:app . .

# Copy application.yml.default to application.yml
COPY --chown=app:app ./config/application.yml.default.docker $RAILS_ROOT/config/application.yml

# Setup config files
COPY --chown=app:app config/agencies.localdev.yml $RAILS_ROOT/config/agencies.yaml
COPY --chown=app:app config/iaa_gtcs.localdev.yml $RAILS_ROOT/config/iaa_gtcs.yaml
COPY --chown=app:app config/iaa_orders.localdev.yml $RAILS_ROOT/config/iaa_orders.yaml
COPY --chown=app:app config/iaa_statuses.localdev.yml $RAILS_ROOT/config/iaa_statuses.yaml
COPY --chown=app:app config/integration_statuses.localdev.yml $RAILS_ROOT/config/integration_statuses.yaml
COPY --chown=app:app config/integrations.localdev.yml $RAILS_ROOT/config/integrations.yaml
COPY --chown=app:app config/partner_account_statuses.localdev.yml $RAILS_ROOT/config/partner_account_statuses.yaml
COPY --chown=app:app config/partner_accounts.localdev.yml $RAILS_ROOT/config/partner_accounts.yaml
COPY --chown=app:app config/service_providers.localdev.yml $RAILS_ROOT/config/service_providers.yaml

# Setup config files
# COPY --chown=app:app ./identity-idp-config/agencies.yml $RAILS_ROOT/config/agencies.yml
# COPY --chown=app:app ./identity-idp-config/iaa_gtcs.yml $RAILS_ROOT/config/iaa_gtcs.yml
# COPY --chown=app:app ./identity-idp-config/iaa_orders.yml $RAILS_ROOT/config/iaa_orders.yml
# Doesn't exist in identity-idp-config
#COPY --chown=app:app ./identity-idp-config/iaa_statuses.yml $RAILS_ROOT/config/iaa_statuses.yaml
# COPY --chown=app:app ./identity-idp-config/integration_statuses.yml $RAILS_ROOT/config/integration_statuses.yml
# COPY --chown=app:app ./identity-idp-config/integrations.yml $RAILS_ROOT/config/integrations.yml
# COPY --chown=app:app ./identity-idp-config/partner_account_statuses.yml $RAILS_ROOT/config/partner_account_statuses.yml
# COPY --chown=app:app ./identity-idp-config/partner_accounts.yml $RAILS_ROOT/config/partner_accounts.yml
# COPY --chown=app:app ./identity-idp-config/service_providers.yml $RAILS_ROOT/config/service_providers.yml

# Copy service provider public keys
# COPY --chown=app:app ../identity-idp-config/certs/sp $RAILS_ROOT/certs/sp
# COPY --chown=app:app ../identity-idp-config/certs $RAILS_ROOT/certs

# Copy public assets: sp-logos
# COPY --chown=app:app ./identity-idp-config/public/assets/images/sp-logos $RAILS_ROOT/app/assets/images/sp-logos
# COPY --chown=app:app ./identity-idp-config/public/assets/images/sp-logos $RAILS_ROOT/public/assets/sp-logos

# Copy keys
COPY --chown=app:app keys.example $RAILS_ROOT/keys

# Copy pwned_passwords.txt
COPY --chown=app:app pwned_passwords/pwned_passwords.txt.sample $RAILS_ROOT/pwned_passwords/pwned_passwords.txt

# Copy robots.txt
COPY --chown=app:app public/ban-robots.txt $RAILS_ROOT/public/robots.txt

# Set user
USER app

# Precompile assets
RUN bundle config build.nokogiri --use-system-libraries
RUN bundle config set --local deployment 'true'
RUN bundle config set --local path $BUNDLE_PATH
RUN bundle config set --local without 'deploy development doc test'
RUN bundle install --jobs $(nproc)
RUN yarn install --production=true --frozen-lockfile --cache-folder .yarn-cache
RUN bundle binstubs --all
RUN bundle exec rake assets:precompile --trace

# Expose the port the app runs on
EXPOSE 3000

# Start the application
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
