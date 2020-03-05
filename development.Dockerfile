# This is the image we run in our local development docker-compose cluster
#   it is built on top of the local production.Dockerfile
FROM identity-idp-production

# Use root for more configuration
USER root

# Re-install dev dependencies
RUN apt-get update \
    && apt-get install -y \
       build-essential \
       git \
       liblzma-dev \
       patch \
       ruby-dev \
       wget 

# Install Chrome for integration tests
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - 
RUN sh -c 'echo "deb https://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
RUN apt-get update
RUN apt-get install -y google-chrome-stable

# Everything happens here from now on   
WORKDIR /upaya

# Remove vendored gems from base image
RUN rm -rf vendor/bundle
# Install dev and test gems on the system
RUN bundle install --system --with development test

# Change back to appuser to run the app
USER appuser

# CMD and EXPOSE are inherited from the base image