FROM ruby:3.3.1-slim

# Set environment variables
ENV PORT=8080
ENV RAILS_ROOT /app
ENV RAILS_ENV development
ENV NODE_ENV development
ENV RAILS_SERVE_STATIC_FILES true
ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_LOG_LEVEL debug
ENV BUNDLE_PATH /usr/local/bundle
ENV YARN_VERSION 1.22.5
ENV NODE_VERSION 20.10.0
ENV BUNDLER_VERSION 2.5.6
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
ENV ASSET_HOST http://localhost:$PORT
ENV DOMAIN_NAME localhost:$PORT
ENV PIV_CAC_SERVICE_URL https://localhost:8443/
ENV PIV_CAC_VERIFY_TOKEN_URL https://localhost:8443/

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
    git-core \
    git-lfs \
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

# RUN curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
#   && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
#   && rm "node-v$NODE_VERSION-linux-x64.tar.xz" \
#   && ln -s /usr/local/bin/node /usr/local/bin/nodejsv

# # Install Yarn
# RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn-archive-keyring.gpg >/dev/null
# RUN echo "deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
# RUN apt-get update && apt-get install -y yarn=1.22.5-1

# Install node + yarn
RUN apt install -y curl
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
ENV NVM_DIR=/root/.nvm
RUN . "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION}
RUN . "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION}
ENV PATH="$NVM_DIR/versions/node/v${NODE_VERSION}/bin/:${PATH}"
RUN node --version
RUN npm install --global yarn
RUN yarn --version

# Download RDS Combined CA Bundle
RUN mkdir -p /usr/local/share/aws \
  && curl https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem > /usr/local/share/aws/rds-combined-ca-bundle.pem \
  && chmod 644 /usr/local/share/aws/rds-combined-ca-bundle.pem

# Create a new user and set up the working directory
RUN addgroup --gid 1000 app && \
    adduser --uid 1000 --gid 1000 --disabled-password --gecos "" app && \
    mkdir -p $RAILS_ROOT && \
    mkdir -p $BUNDLE_PATH && \
    mkdir -p $RAILS_ROOT/tmp/pids && \
    mkdir -p $RAILS_ROOT/log

# Setup timezone data
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create the working directory
WORKDIR $RAILS_ROOT

COPY .ruby-version $RAILS_ROOT/.ruby-version
COPY Gemfile $RAILS_ROOT/Gemfile
COPY Gemfile.lock $RAILS_ROOT/Gemfile.lock

RUN bundle config build.nokogiri --use-system-libraries
RUN bundle config set --local deployment 'true'
RUN bundle config set --local path $BUNDLE_PATH
RUN bundle config set --local without 'deploy production test'
RUN bundle install --jobs $(nproc)
RUN bundle binstubs --all

COPY package.json $RAILS_ROOT/package.json
COPY yarn.lock $RAILS_ROOT/yarn.lock
RUN yarn install --production=true --frozen-lockfile --cache-folder .yarn-cache

# Add the application code
COPY ./lib ./lib
COPY ./app ./app
COPY ./config ./config
COPY ./config.ru ./config.ru
COPY ./db ./db
COPY ./deploy ./deploy
COPY ./bin ./bin
COPY ./public ./public
COPY ./scripts ./scripts
COPY ./spec ./spec
COPY ./Rakefile ./Rakefile
COPY ./Makefile ./Makefile
COPY ./babel.config.js ./babel.config.js
COPY ./webpack.config.js ./webpack.config.js
COPY ./.browserslistrc ./.browserslistrc

# Copy keys
COPY keys.example $RAILS_ROOT/keys

# Copy big files
ARG LARGE_FILES_USER
ARG LARGE_FILES_TOKEN
RUN mkdir -p $RAILS_ROOT/geo_data && chmod 755 $RAILS_ROOT/geo_data
RUN mkdir -p $RAILS_ROOT/pwned_passwords && chmod 755 $RAILS_ROOT/pwned_passwords
# RUN git clone --depth 1 https://$LARGE_FILES_USER:$LARGE_FILES_TOKEN@gitlab.login.gov/lg-public/idp-large-files.git && \
#     cp idp-large-files/GeoIP2-City.mmdb $RAILS_ROOT/geo_data/ && \
#     cp idp-large-files/GeoLite2-City.mmdb $RAILS_ROOT/geo_data/ && \
#     cp idp-large-files/pwned-passwords.txt $RAILS_ROOT/pwned_passwords/ && \
#     rm -r idp-large-files
RUN mkdir -p /usr/local/share/aws && \
    curl https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem > /usr/local/share/aws/rds-combined-ca-bundle.pem

# Copy robots.txt
COPY public/ban-robots.txt $RAILS_ROOT/public/robots.txt

# Copy application.yml.default to application.yml
COPY ./config/application.yml.default.prod $RAILS_ROOT/config/application.yml

# Setup config files
COPY config/agencies.localdev.yml $RAILS_ROOT/config/agencies.yml
COPY config/iaa_gtcs.localdev.yml $RAILS_ROOT/config/iaa_gtcs.yml
COPY config/iaa_orders.localdev.yml $RAILS_ROOT/config/iaa_orders.yml
COPY config/iaa_statuses.localdev.yml $RAILS_ROOT/config/iaa_statuses.yml
COPY config/integration_statuses.localdev.yml $RAILS_ROOT/config/integration_statuses.yml
COPY config/integrations.localdev.yml $RAILS_ROOT/config/integrations.yml
COPY config/partner_account_statuses.localdev.yml $RAILS_ROOT/config/partner_account_statuses.yml
COPY config/partner_accounts.localdev.yml $RAILS_ROOT/config/partner_accounts.yml
COPY certs.example $RAILS_ROOT/certs
COPY config/service_providers.localdev.yml $RAILS_ROOT/config/service_providers.yml

# Precompile assets
RUN bundle exec rake assets:precompile --trace

# Setup setup files
COPY db-init.sh $RAILS_ROOT/db-init.sh
RUN chmod +x ./db-init.sh

ARG ARG_CI_COMMIT_BRANCH="branch_placeholder"
ARG ARG_CI_COMMIT_SHA="sha_placeholder"
RUN mkdir -p $RAILS_ROOT/public/api/
RUN echo "{\"branch\":\"$ARG_CI_COMMIT_BRANCH\",\"git_sha\":\"$ARG_CI_COMMIT_SHA\"}" > $RAILS_ROOT/public/api/deploy.json

# Generate and place SSL certificates for puma
RUN openssl req -x509 -sha256 -nodes -newkey rsa:2048 -days 1825 \
    -keyout $RAILS_ROOT/keys/localhost.key \
    -out $RAILS_ROOT/keys/localhost.crt \
    -subj "/C=US/ST=Fake/L=Fakerton/O=Dis/CN=localhost"

# make everything the proper perms after everything is initialized
RUN chown -R app:app $RAILS_ROOT/tmp && \
    chown -R app:app $RAILS_ROOT/log && \
    chown -R app:app $RAILS_ROOT/keys && \
    find $RAILS_ROOT -type d | xargs chmod 755

# Expose the port the app runs on
EXPOSE $PORT

# Set user
USER app

# Start the application
CMD bundle exec puma -b "tcp://0.0.0.0:$PORT"