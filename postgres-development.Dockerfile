# Switch to base image and add in Gems
FROM postgres:13.4

WORKDIR /idp

# Set MAKEFLAGS to scale with compute capacity
ENV MAKEFLAGS "-j$(nproc)"
ENV NODE_ENV=development
ENV NODE_PATH=/usr/local/node_modules
ENV DOCKER_DB_HOST=localhost
ENV POSTGRES_DB=identity_idp_test
ENV POSTGRES_USER=postgres_user
ENV POSTGRES_PASSWORD=postgres_password
ENV POSTGRES_HOST_AUTH_METHOD=trust
ENV RUBY_VER=3.0.4
ENV NODE_VER=14

RUN apt-get update -q
RUN apt-get install -qy \
  procps \
  curl \
  ca-certificates \
  gnupg2 \
  build-essential \
  git \
  libpq-dev \
  sudo --no-install-recommends

RUN curl -sL https://deb.nodesource.com/setup_14.x | sudo bash -
RUN curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg >/dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
RUN apt-get install -qy \
  nodejs --no-install-recommends

RUN apt-get clean

RUN gpg2 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
RUN curl -sSL https://get.rvm.io | bash -s stable
RUN usermod -a -G rvm root
RUN /bin/bash -l -c ". /etc/profile.d/rvm.sh && rvm install 3.0.4"
RUN /bin/bash -l -c ". /etc/profile.d/rvm.sh && rvm use 3.0.4 --default"

COPY . /idp

RUN /bin/bash -l -c ". /etc/profile.d/rvm.sh && gem install bundler --conservative"
RUN /bin/bash -l -c ". /etc/profile.d/rvm.sh && gem install foreman --conservative && gem update foreman"
RUN /bin/bash -l -c ". /etc/profile.d/rvm.sh && bundle install --without deploy production"

RUN npm install --global yarn
RUN yarn install
RUN yarn cache clean

COPY config/application.yml.default config/application.yml
COPY config/service_providers.localdev.yml config/service_providers.yml
COPY config/agencies.localdev.yml config/agencies.yml
COPY config/iaa_gtcs.localdev.yml config/iaa_gtcs.yml
COPY config/iaa_orders.localdev.yml config/iaa_orders.yml
COPY config/iaa_statuses.localdev.yml config/iaa_statuses.yml
COPY config/integration_statuses.localdev.yml config/integration_statuses.yml
COPY config/integrations.localdev.yml config/integrations.yml
COPY config/partner_account_statuses.localdev.yml config/partner_account_statuses.yml
COPY config/partner_accounts.localdev.yml config/partner_accounts.yml
COPY certs.example certs
COPY keys.example keys

RUN chown postgres:postgres /idp --recursive
COPY docker/postgres_schema.sh /docker-entrypoint-initdb.d/
