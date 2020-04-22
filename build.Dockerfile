# Build base image - Use to build only, not as a final base.
# Docker multi-stage builds are used to copy output from this heavy image into others
FROM logindotgov/base

# Everything happens here from now on   
WORKDIR /upaya

# Prepare for Gem builds
RUN apt-get update \
    && apt-get install -y \
       build-essential \
       liblzma-dev \
       patch \
       ruby-dev \
    && gem install bundler --conservative

CMD ["sh"]
