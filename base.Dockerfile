# Base for all IdP images
FROM ruby:2.6-slim

# Enable package fetch over https and add a few core tools
RUN apt-get update \
    && apt-get install -y curl \
    && curl -sL https://deb.nodesource.com/setup_12.x | bash - \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       apt-transport-https \
       curl \
       git \
       postgresql-client \
       libpq-dev \
       nodejs \
       yarn \
    && rm -rf /var/lib/apt/lists/*

# Add application user 
RUN groupadd -r appuser \
    && useradd --system --create-home --gid appuser appuser

CMD ["sh"]
