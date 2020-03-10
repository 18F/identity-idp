# Build base image - Use to build only, not as a final base!
FROM identity-rails_base

# Everything happens here from now on   
WORKDIR /upaya

# Prepare for Gem builds
RUN apt-get update \
    && apt-get install -y \
       build-essential \
       git \
       liblzma-dev \
       patch \
       ruby-dev \
    && gem install bundler --conservative

CMD ["sh"]
