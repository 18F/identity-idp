FROM ruby:3.2.2-slim

# Set environment variables
ARG ARG_CI_ENVIRONMENT_SLUG="placeholder"
ARG ARG_CI_COMMIT_BRANCH="branch_placeholder"
ARG ARG_CI_COMMIT_SHA="sha_placeholder"
ENV CI_ENVIRONMENT_SLUG=${ARG_CI_ENVIRONMENT_SLUG}
ENV CI_COMMIT_BRANCH=${ARG_CI_COMMIT_BRANCH}
ENV CI_COMMIT_SHA=${ARG_CI_COMMIT_SHA}
ENV RAILS_ROOT /app
ENV RAILS_ENV production
ENV NODE_ENV production
ENV RAILS_SERVE_STATIC_FILES true
ENV RAILS_LOG_TO_STDOUT true
ENV LOGIN_CONFIG_FILE $RAILS_ROOT/tmp/application.yml
ENV RAILS_LOG_LEVEL debug
ENV BUNDLE_PATH /usr/local/bundle
ENV YARN_VERSION 1.22.5
ENV NODE_VERSION 18.16.1
ENV BUNDLER_VERSION 2.4.4
ENV POSTGRES_SSLMODE prefer
ENV POSTGRES_NAME idp
ENV POSTGRES_HOST postgres
ENV POSTGRES_USERNAME postgres
ENV POSTGRES_PASSWORD postgres
ENV POSTGRES_WORKER_SSLMODE prefer
ENV POSTGRES_WORKER_NAME idp-worker-jobs
ENV POSTGRES_WORKER_HOST postgres-worker
ENV POSTGRES_WORKER_USERNAME postgres
ENV POSTGRES_WORKER_PASSWORD postgres
ENV REDIS_IRS_ATTEMPTS_API_URL redis://redis:6379/2
ENV REDIS_THROTTLE_URL redis://redis:6379/1
ENV REDIS_URL redis://redis:6379
ENV ASSET_HOST http://localhost:3000
ENV DOMAIN_NAME localhost:3000
ENV PIV_CAC_SERVICE_URL https://localhost:8443/
ENV PIV_CAC_VERIFY_TOKEN_URL https://localhost:8443/ 

RUN echo Env Value : $CI_ENVIRONMENT_SLUG

# Prevent documentation installation
RUN echo 'path-exclude=/usr/share/doc/*' > /etc/dpkg/dpkg.cfg.d/00_nodoc && \
    echo 'path-exclude=/usr/share/man/*' >> /etc/dpkg/dpkg.cfg.d/00_nodoc && \
    echo 'path-exclude=/usr/share/groff/*' >> /etc/dpkg/dpkg.cfg.d/00_nodoc && \
    echo 'path-exclude=/usr/share/info/*' >> /etc/dpkg/dpkg.cfg.d/00_nodoc && \
    echo 'path-exclude=/usr/share/lintian/*' >> /etc/dpkg/dpkg.cfg.d/00_nodoc && \
    echo 'path-exclude=/usr/share/linda/*' >> /etc/dpkg/dpkg.cfg.d/00_nodoc

# Create a new user and set up the working directory
RUN addgroup --gid 1000 app && \
    adduser --uid 1000 --gid 1000 --disabled-password --gecos "" app && \
    mkdir -p $RAILS_ROOT && \
    mkdir -p $BUNDLE_PATH && \
    chown -R app:app $RAILS_ROOT && \
    chown -R app:app $BUNDLE_PATH

# Setup timezone data
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    git-core \
    curl \
    zlib1g-dev \
    build-essential \
    libssl-dev \
    libreadline-dev \
    libyaml-dev \
    libsqlite3-dev \
    sqlite3 \
    libxml2-dev \
    libxslt1-dev \
    libcurl4-openssl-dev \
    software-properties-common \
    libffi-dev \
    libpq-dev \
    unzip && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejsv

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn-archive-keyring.gpg >/dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y yarn=1.22.5-1

# Create the working directory
WORKDIR $RAILS_ROOT

# Set user
USER app

COPY .ruby-version $RAILS_ROOT/.ruby-version
COPY Gemfile $RAILS_ROOT/Gemfile
COPY Gemfile.lock $RAILS_ROOT/Gemfile.lock

RUN bundle config build.nokogiri --use-system-libraries
RUN bundle config set --local deployment 'true'
RUN bundle config set --local path $BUNDLE_PATH
RUN bundle config set --local without 'deploy development doc test'
RUN bundle install --jobs $(nproc)
RUN bundle binstubs --all

COPY package.json $RAILS_ROOT/package.json
COPY yarn.lock $RAILS_ROOT/yarn.lock
RUN yarn install --production=true --frozen-lockfile --cache-folder .yarn-cache

COPY <<EOF $RAILS_ROOT/public/deploy.json
{
  "branch": "$CI_COMMIT_BRANCH",
  "git_sha":"$CI_COMMIT_SHA"
}
EOF

# Add the application code
COPY --chown=app:app ./lib ./lib
COPY --chown=app:app ./app ./app
COPY --chown=app:app ./config ./config
COPY --chown=app:app ./config.ru ./config.ru
COPY --chown=app:app ./db ./db
COPY --chown=app:app ./deploy ./deploy
COPY --chown=app:app ./bin ./bin
COPY --chown=app:app ./public ./public
COPY --chown=app:app ./scripts ./scripts
COPY --chown=app:app ./spec ./spec
COPY --chown=app:app ./vendor ./vendor
COPY --chown=app:app ./Rakefile ./Rakefile
COPY --chown=app:app ./Makefile ./Makefile
COPY --chown=app:app ./babel.config.js ./babel.config.js
COPY --chown=app:app ./webpack.config.js ./webpack.config.js
COPY --chown=app:app ./.browserslistrc ./.browserslistrc

# Copy keys
COPY --chown=app:app keys.example $RAILS_ROOT/keys

# Copy pwned_passwords.txt
COPY --chown=app:app pwned_passwords/pwned_passwords.txt.sample $RAILS_ROOT/pwned_passwords/pwned_passwords.txt

# Copy robots.txt
COPY --chown=app:app public/ban-robots.txt $RAILS_ROOT/public/robots.txt

# Copy application.yml.default to application.yml
COPY --chown=app:app ./config/application.yml.default.docker $RAILS_ROOT/config/application.yml

# Generate and place SSL certificates for puma
RUN openssl req -x509 -sha256 -nodes -newkey rsa:2048 -days 1825 \
    -keyout $RAILS_ROOT/keys/localhost.key \
    -out $RAILS_ROOT/keys/localhost.crt \
    -subj "/C=US/ST=Fake/L=Fakerton/O=Dis/CN=localhost"

# Precompile assets
RUN bundle exec rake assets:precompile --trace

# Setup config files
COPY --chown=app:app config/agencies.localdev.yml $RAILS_ROOT/config/agencies.yml
COPY --chown=app:app config/iaa_gtcs.localdev.yml $RAILS_ROOT/config/iaa_gtcs.yml
COPY --chown=app:app config/iaa_orders.localdev.yml $RAILS_ROOT/config/iaa_orders.yml
COPY --chown=app:app config/iaa_statuses.localdev.yml $RAILS_ROOT/config/iaa_statuses.yml
COPY --chown=app:app config/integration_statuses.localdev.yml $RAILS_ROOT/config/integration_statuses.yml
COPY --chown=app:app config/integrations.localdev.yml $RAILS_ROOT/config/integrations.yml
COPY --chown=app:app config/partner_account_statuses.localdev.yml $RAILS_ROOT/config/partner_account_statuses.yml
COPY --chown=app:app config/partner_accounts.localdev.yml $RAILS_ROOT/config/partner_accounts.yml
COPY --chown=app:app certs.example $RAILS_ROOT/certs
COPY --chown=app:app config/service_providers.localdev.yml $RAILS_ROOT/config/service_providers.yaml

# Expose the port the app runs on
EXPOSE 3000

# Start the application
# CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
CMD ["bundle", "exec", "puma", "-b", "ssl://0.0.0.0:3000?key=/app/keys/localhost.key&cert=/app/keys/localhost.crt"]
