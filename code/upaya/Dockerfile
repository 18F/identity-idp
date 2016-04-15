FROM rails:4.2.6

MAINTAINER Eric Maland <eric.maland@gsa.gov>

WORKDIR /upaya

COPY Gemfile /upaya
COPY Gemfile.lock /upaya
ENV RAILS_ENV docker
ENV NEW_RELIC_AGENT_ENABLED false

RUN bundler install --without deployment deploy test

COPY . /upaya

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0"]
