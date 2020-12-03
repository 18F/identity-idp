Login.gov Identity Provider (IdP)
=================================

[![Build Status](https://circleci.com/gh/18F/identity-idp.svg?style=svg)](https://circleci.com/gh/18F/identity-idp)
[![Code Climate](https://api.codeclimate.com/v1/badges/e78d453f7cbcac64a664/maintainability)](https://codeclimate.com/github/18F/identity-idp/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/e78d453f7cbcac64a664/test_coverage)](https://codeclimate.com/github/18F/identity-idp/test_coverage)
[![security](https://hakiri.io/github/18F/identity-idp/master.svg)](https://hakiri.io/github/18F/identity-idp/master)

Login.gov is the public's one account for government. Use one account and password for secure, private access to participating government agencies.

This repository contains the core code base and documentation for the identity management system powering secure.login.gov.

## Contributing to this code base

Thank you for your interest in contributing to the login.gov IdP! For complete instructions on how to contribute code, please read through our [CONTRIBUTING.md](CONTRIBUTING.md) documentation.

## Creating your local development environment

There are two methods that we recommend for installing for local development. One is container based with Docker, while the other is focused on your local machine's installation (advanced). For those who are not familiar with setting up local environments on your machine, we recommend [installing with Docker](#installing-with-docker).

### Installing on your local machine

This installation method is meant for those who are familiar with setting up local development environments on their machines.

1. To start, make sure you have the following dependencies installed and a working development environment:

- Ruby 2.6
- [PostgreSQL](http://www.postgresql.org/download/)
- [Redis 5+](http://redis.io/)
- [Node.js v14.x.x](https://nodejs.org)
- [Yarn](https://yarnpkg.com/en/)

We recommend using [Homebrew](https://brew.sh/), [rbenv](https://github.com/rbenv/rbenv), [nvm](https://github.com/nvm-sh/nvm) or other version management tooling when installing your dependencies. While we don't anticipate changing these frequently, this will ensure that you will be able to easily switch to different versions as needed.

2. Test that you have Postgres and Redis running.

  For example, if you've installed with Homebrew, you can start the services like this:

  ```
  $ brew services start redis
  $ brew services start postgresql
  ```

3. Create the development and test databases:

  ```
  $ psql -c "CREATE DATABASE upaya_development;"
  $ psql -c "CREATE DATABASE upaya_test;"
  ```

  Q: Why "Upaya"?

  A: "skill in means" https://en.wikipedia.org/wiki/Upaya

4. Run the following command to set up your local environment:

  ```
  $ make setup
  ```

  This command copies sample configuration files, installs required gems
  and sets up the database. Check out our Makefile commands to learn more about what this command does: https://github.com/18F/identity-idp/blob/master/Makefile

5. Now that you have you have everything installed, you can run the following command to start your local server:

  ```
  $ make run
  ```

  You should now be able to go to open up your favorite browser, go to `localhost:3000` and see your local development environment running.

#### Running tests locally

  Login.gov uses the following tools for our testing:

  - [RSpec](https://relishapp.com/rspec/rspec-core/docs/command-line)
  - [Guard](https://github.com/guard/guard-rspec)
  - [Mocha documentation](https://mochajs.org/)

  To run our full test suite locally, use the following command:

  ```
  $ make test
  ```

  Use the following command to run a subset of our test suite, excluding slower tests:

  ```
  $ make fast_test
  ```

  Check out our Makefile commands learn more about how you can customize this command to run specific tests using rspec: https://github.com/18F/identity-idp/blob/master/Makefile#L41

##### Running smoke tests

  The smoke tests are a series of RSpec tests designed to run against deployed environments. To run them against the local Rails server:

  ```bash
  ./bin/smoke_test --local
  ```

  To run the smoke tests against a deployed server, make sure you set up a `.env` file with the right configuration values, see [monitor_config.rb](spec/support/monitor/monitor_config.rb) for the full list of environment variables used. The script below will `source` that file and add the variables to the environment.

  ```bash
  MONITOR_ENV=INT ./bin/smoke_test --remote
  ```

#### Speeding up local development and testing

  To automatically run the test that corresponds to the file you are editing,
  run `bundle exec guard` with the env var `GUARD_RSPEC_CMD` set to your preferred
  command for running `rspec`. For example, if you use [Zeus](https://github.com/burke/zeus),
  you would set the env var to `zeus rspec`:
  ```console
  GUARD_RSPEC_CMD="zeus rspec" bundle exec guard
  ```

  If you don't specify the `GUARD_RSPEC_CMD` env var, it will default to
  `bundle exec rspec`.

  We also recommend setting up a shell alias for running this command, such as:
  ```console
  alias idpguard='GUARD_RSPEC_CMD="zeus rspec" bundle exec guard'
  ```

#### Viewing email messages

  Login.gov uses a tool called [Mailcatcher](https://github.com/sj26/mailcatcher) to view email messages locally. When Mailcatcher is running, visit http://localhost:1080/ to see them.

  We spin up a Mailcatcher process be default through `make run`, but if you want to run Mailcatcher as a standalone process, just run:

  ```
  $ mailcatcher
  ```

  If you would like to run the application on a different port:

  * Change the port number for `mailer_domain_name` and `domain_name` in `config/application.yml`
  * Run the app on your desired port like `make run PORT=1234`

#### Translations

  Login.gov translates the IdP into English, French and Spanish. To help us handle extra newlines and make sure we wrap lines consistently, we have a script called `./scripts/normalize-yaml` that helps format YAML consistently. After importing translations (or making changes to the *.yml files with strings, run this for the IdP app:

  ```
  $ make normalize_yaml
  ```

  If you would like to preview the translations on a particular page, use the Language dropdown in the footer of the website. To manually override a locale, add the locale as the first segment of the URL:
  - http://localhost:3000 becomes http://localhost:3000/es
  - http://localhost:3000/sign_up/enter_email becomes http://localhost:3000/es/sign_up/enter_email  

#### Viewing outbound SMS messages and phone calls

  To see outbound SMS messages and phone calls, visit `http://localhost:3000/test/telephony`.

#### Setting up Geolocation

Login.gov uses MaxMind Geolite2 for geolocation. To test geolocation locally, you will need to add a copy of the Geolite2-City database to the IdP.

The Geolite2-City database can be downloaded from MaxMind's site at [https://dev.maxmind.com/geoip/geoip2/geolite2/](https://dev.maxmind.com/geoip/geoip2/geolite2/).

Download the GeoIP2 Binary and save it at `geo_data/GeoLite2-City.mmdb`.
The app will start using that Geolite2 file for geolocation after restart.

### Installing with Docker

See the [Docker documentation](./docs/Docker.md) to install the IdP as a container.
