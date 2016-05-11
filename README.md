[![Build Status](https://travis-ci.org/18F/identity-idp.svg?branch=master)](https://travis-ci.org/18F/identity-idp)
[![Code Climate](https://codeclimate.com/github/18F/identity-idp/badges/gpa.svg)](https://codeclimate.com/github/18F/identity-idp)
[![Test Coverage](https://codeclimate.com/github/18F/identity-idp/badges/coverage.svg)](https://codeclimate.com/github/18F/identity-idp/coverage)

# Identity-IdP (Upaya)
A proof-of-concept Identity Management System

#### Dependencies

- Ruby 2.3.0
- [Postgresql](http://www.postgresql.org/download/)
- [Redis 2.8+](http://redis.io/)
- [Node.js v4.4.x](https://nodejs.org)
- libxmlsec1

### Getting Started with Docker

We have a pre-built development environment made with [Docker Compose].
  * On non-Linux systems this will involve installing [Docker
    Toolbox (v1.10+)](https://www.docker.com/products/docker-toolbox) and
    starting a Docker Machine VM by launching the `Docker Quickstart Terminal`
    app.

1. Copy the sample configuration files:

        $ bin/setup --docker

1. Build/download the container images:

        $ docker-compose build

1. Start the app:

        $ docker-compose up -d

1. Setup the database(s):

        $ docker-compose run --rm web rake db:setup RAILS_ENV=development

        $ docker-compose run --rm web rake db:setup RAILS_ENV=test

Once the docker images are up and running, the app will be accessible
at `http://localhost:3000/`.  Email messages will be visible in MailCatcher
at `http://localhost:1080/`.
  * On non-Linux platforms, `localhost` will need to be replaced with the
    IP address of your Docker Machine VM, which is `192.168.99.100` by default.
    When you launch the `Docker Quickstart Terminal` app on a Mac, it will tell
    you which machine and IP are in use:

    ![docker](http://cl.ly/1Q0Q1H1i3J3c/download/Screen%20Shot%202016-04-27%20at%202.03.32%20PM.png)


More useful Docker commands:

* Stop this running container: `docker-compose stop`
* Stop the Docker Machine VM: `docker-machine stop`
* Stop and delete the containers: `docker-compose down`
* Open a shell in the web container: `docker-compose run --rm web bash`

See the Docker Compose [docs](https://docs.docker.com/compose/install/) for
more information.

[Docker Compose]: (https://docs.docker.com/compose/install/)

### Getting Started Locally

1. Make sure you have a working development environment with all the
[dependencies](#dependencies) installed. On a Mac, the easiest way
to set up a development environment is by running our [Laptop]
script. The script will install all of this project's dependencies,
except for `libxmlsec1`, which you can install with Homebrew:

        $ brew install libxmlsec1

1. Make sure Postgres and Redis are running. For example, on OS X:

        $ brew services start redis postgres

1. Run the following command to set up the environment:

        $ bin/setup

   This command copies sample configuration files, installs required gems
   and sets up the database.

1. Run the app server with:

        $ foreman start

[Laptop]: https://github.com/18F/laptop

### Running Tests

To run all the tests:

    $ bundle exec rspec

See RSpec [docs](https://relishapp.com/rspec/rspec-core/docs/command-line) for
more information.

### Deploying

We currently run `dev` and `qa` environments at https://upaya-idp-dev.18f.gov
and https://upaya-idp-qa.18f.gov. Core developers can deploy to those hosts
with [Capistrano](http://capistranorb.com) using the following command:

```
cap <env/stage> deploy
```

You will need to provide a copy of your SSH public key and you may need to
provide your IP address if you are not in a GSA building or on the GSA VPN.
Post a message in the Slack channel if you need help.

## More Information

**Notice:** This project is still in alpha.

### Why 'Upaya'?

"skill in means" https://en.wikipedia.org/wiki/Upaya
