# Base for all IdP images
FROM ruby:2.5-slim

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

# Add application user 
RUN groupadd -r appuser \
    && useradd --system --create-home --gid appuser appuser

CMD ["sh"]
