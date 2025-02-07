#########################################################################
# This is a "production-ready" image build for the IDP that is suitable
# for deployment.
# This is a multi-stage build.  This stage just builds and downloads
# gems and yarn stuff and large files.  We have it so that we can
# avoid having build-essential and the large-files token be in the
# main image.
#########################################################################
FROM public.ecr.aws/docker/library/ruby:3.4.1-slim as builder

# Set environment variables
ENV RAILS_ROOT /app
ENV RAILS_ENV production
ENV NODE_ENV production
ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_LOG_LEVEL debug
ENV BUNDLE_PATH /app/vendor/bundle
ENV YARN_VERSION 1.22.5
ENV NODE_VERSION 22.11.0
ENV BUNDLER_VERSION 2.6.3

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    openssh-client \
    git-core \
    build-essential \
    git-lfs \
    curl \
    zlib1g-dev \
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
    xz-utils \
    unzip && \
    rm -rf /var/lib/apt/lists/*

# get the large files
WORKDIR /
ARG LARGE_FILES_USER
ARG LARGE_FILES_TOKEN
RUN git clone --depth 1 https://$LARGE_FILES_USER:$LARGE_FILES_TOKEN@gitlab.login.gov/lg-public/idp-large-files.git

# Set the working directory
WORKDIR $RAILS_ROOT

# Install Node
RUN curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejsv

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarn-archive-keyring.gpg >/dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/yarn.list && apt-get install -y yarn=1.22.5-1

# bundle install
COPY .ruby-version $RAILS_ROOT/.ruby-version
COPY Gemfile $RAILS_ROOT/Gemfile
COPY Gemfile.lock $RAILS_ROOT/Gemfile.lock
RUN bundle config build.nokogiri --use-system-libraries
RUN bundle config set --local deployment 'true'
RUN bundle config set --local path $BUNDLE_PATH
RUN bundle config set --local without 'deploy development doc test'
RUN bundle install --jobs $(nproc)
RUN bundle binstubs --all

# Yarn install
COPY ./package.json ./package.json
COPY ./yarn.lock ./yarn.lock
# Workspace packages are installed by Yarn via symlink to the original source, and need to be present
COPY ./app/javascript/packages ./app/javascript/packages
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

# Copy robots.txt
COPY public/ban-robots.txt $RAILS_ROOT/public/robots.txt

# Copy application.yml.default to application.yml
COPY ./config/application.yml.default.k8s_deploy $RAILS_ROOT/config/application.yml

# Precompile assets
RUN SKIP_YARN_INSTALL=true bundle exec rake assets:precompile && rm -r node_modules/ && rm -r .yarn-cache/

# get service_providers.yml and related files
ARG SERVICE_PROVIDERS_KEY
RUN echo "$SERVICE_PROVIDERS_KEY" > private_key_file ; chmod 600 private_key_file
RUN GIT_SSH_COMMAND='ssh -i private_key_file -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new' git clone --depth 1 git@github.com:18F/identity-idp-config.git
RUN mkdir -p $RAILS_ROOT/config/ $RAILS_ROOT/public/assets/images
RUN cp identity-idp-config/*.yml $RAILS_ROOT/config/
RUN cp -rp identity-idp-config/certs $RAILS_ROOT/
RUN cp -rp identity-idp-config/public/assets/images/sp-logos $RAILS_ROOT/public/assets/images/

# set up deploy.json
ARG ARG_CI_COMMIT_BRANCH="branch_placeholder"
ARG ARG_CI_COMMIT_SHA="sha_placeholder"
RUN mkdir -p $RAILS_ROOT/public/api/
RUN echo "{\"branch\":\"$ARG_CI_COMMIT_BRANCH\",\"git_sha\":\"$ARG_CI_COMMIT_SHA\"}" > $RAILS_ROOT/public/api/deploy.json

# Download RDS Combined CA Bundle
RUN mkdir -p /usr/local/share/aws \
  && curl https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem > /usr/local/share/aws/rds-combined-ca-bundle.pem  \
  && chmod 644 /usr/local/share/aws/rds-combined-ca-bundle.pem

# Generate and place SSL certificates for puma
RUN openssl req -x509 -sha256 -nodes -newkey rsa:2048 -days 1825 \
    -keyout $RAILS_ROOT/keys/localhost.key \
    -out $RAILS_ROOT/keys/localhost.crt \
    -subj "/C=US/ST=Fake/L=Fakerton/O=Dis/CN=localhost" && \
    chmod 644 $RAILS_ROOT/keys/localhost.key $RAILS_ROOT/keys/localhost.crt

#########################################################################
# This is the main image.
#########################################################################
FROM public.ecr.aws/docker/library/ruby:3.4.1-slim as main

# Set environment variables
ENV RAILS_ROOT /app
ENV RAILS_ENV production
ENV NODE_ENV production
ENV RAILS_SERVE_STATIC_FILES true
ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_LOG_LEVEL debug
ENV BUNDLE_PATH /app/vendor/bundle
ENV BUNDLER_VERSION 2.6.3
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
ENV REMOTE_ADDRESS_HEADER X-Forwarded-For

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    openssh-client \
    git-core \
    curl \
    zlib1g-dev \
    libssl-dev \
    libreadline-dev \
    libyaml-dev \
    libxml2-dev \
    libxslt1-dev \
    libcurl4-openssl-dev \
    libffi-dev \
    libpq-dev \
    unzip && \
    rm -rf /var/lib/apt/lists/*

# get RDS combined CA bundle
COPY --from=builder /usr/local/share/aws/rds-combined-ca-bundle.pem /usr/local/share/aws/rds-combined-ca-bundle.pem

# Create a new user and set up the working directory
RUN addgroup --gid 1000 app && \
    adduser --uid 1000 --gid 1000 --disabled-password --gecos "" app && \
    mkdir -p $RAILS_ROOT && \
    mkdir -p $RAILS_ROOT/tmp/pids && \
    mkdir -p $RAILS_ROOT/log

# Setup timezone data
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create the working directory
WORKDIR $RAILS_ROOT

# set bundler up
RUN bundle config build.nokogiri --use-system-libraries
RUN bundle config set --local deployment 'true'
RUN bundle config set --local path $BUNDLE_PATH
RUN bundle config set --local without 'deploy development doc test'

# Copy big files
RUN mkdir -p $RAILS_ROOT/geo_data && chmod 755 $RAILS_ROOT/geo_data
RUN mkdir -p $RAILS_ROOT/pwned_passwords && chmod 755 $RAILS_ROOT/pwned_passwords
COPY --from=builder /idp-large-files/GeoIP2-City.mmdb $RAILS_ROOT/geo_data/
COPY --from=builder /idp-large-files/GeoLite2-City.mmdb $RAILS_ROOT/geo_data/
COPY --from=builder /idp-large-files/pwned-passwords.txt $RAILS_ROOT/pwned_passwords/pwned_passwords.txt

# copy in all the stuff from the builder image
COPY --from=builder $RAILS_ROOT $RAILS_ROOT

# copy keys in
COPY --from=builder $RAILS_ROOT/keys/localhost.key $RAILS_ROOT/keys/
COPY --from=builder $RAILS_ROOT/keys/localhost.crt $RAILS_ROOT/keys/

# make everything the proper perms after everything is initialized
RUN chown -R app:app $RAILS_ROOT/tmp && \
    chown -R app:app $RAILS_ROOT/log && \
    find $RAILS_ROOT -type d | xargs -d '\n' chmod 755

# get rid of suid/sgid binaries
RUN find / -perm /4000 -type f | xargs chmod u-s
RUN find / -perm /2000 -type f | xargs chmod g-s

# Expose the port the app runs on
EXPOSE 3000

# Set user
USER app

# Start the application
CMD ["bundle", "exec", "puma", "-b", "ssl://0.0.0.0:3000?key=/app/keys/localhost.key&cert=/app/keys/localhost.crt"]

