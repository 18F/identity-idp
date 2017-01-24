Identity-IdP (Upaya)
====================

[![Build Status](https://travis-ci.org/18F/identity-idp.svg?branch=master)](https://travis-ci.org/18F/identity-idp)
[![Code Climate](https://codeclimate.com/github/18F/identity-idp/badges/gpa.svg)](https://codeclimate.com/github/18F/identity-idp)
[![Test Coverage](https://codeclimate.com/github/18F/identity-idp/badges/coverage.svg)](https://codeclimate.com/github/18F/identity-idp/coverage)
[![security](https://hakiri.io/github/18F/identity-idp/master.svg)](https://hakiri.io/github/18F/identity-idp/master)
[![accessibility](https://continua11y.18f.gov/18F/identity-idp.svg?branch=master)](https://continua11y.18f.gov/18F/identity-idp)

A Identity Management System powering login.gov.

### Local development

#### Dependencies

- Ruby 2.3.3
- [Postgresql](http://www.postgresql.org/download/)
- [Redis 2.8+](http://redis.io/)
- [Node.js v4.4.x](https://nodejs.org)

Testing dependencies:
- [PhantomJS](http://phantomjs.org)

#### Setting up and running the app

1. Make sure you have a working development environment with all the
  [dependencies](#dependencies) installed. On OS X, the easiest way
  to set up a development environment is by running our [Laptop]
  script. The script will install all of this project's dependencies.

1. Make sure Postgres and Redis are running.

  For example, if you've installed the laptop script on OS X, you can start the services like this:

  ```
  $ brew services start redis
  $ brew services start postgres
  ```

1. Run the following command to set up the environment:

  ```
  $ make setup
  ```

  This command copies sample configuration files, installs required gems
  and sets up the database.

1. Run the app server with:

  ```
  $ make run
  ```

Before making any commits, you'll also need to run `overcommit --sign.`
This verifies that the commit hooks defined in our `.overcommit.yml` file are
the ones we expect. Each change to the `.overcommit.yml` file, including the initial install
performed in the setup script, will necessitate a new signature.

For more information, see [overcommit](https://github.com/brigade/overcommit)


If you want to develop without and internet connection, you can set
`RAILS_OFFLINE=1` in your environment. This disables the `mx` record
check on email addresses.

If you want to measure the app's performance in development, set the
`rack_mini_profiler` option to `'on'` in `config/application.yml` and
restart the server. See the [rack_mini_profiler] gem for more details.

[Laptop]: https://github.com/18F/laptop
[rack_mini_profiler]: https://github.com/MiniProfiler/rack-mini-profiler

#### Testing Analytics

If you want to visualize and query the event and log data, you can install
the latest versions of Elasticsearch, Logstash, and Kibana.
On OS X, the easiest way is with Homebrew:

```
brew tap homebrew/services

brew install elasticsearch logstash kibana # or brew upgrade if already installed

brew services start elasticsearch
brew services start kibana
```

Start logstash by running this command from this repo's root directory:
```
logstash -f logstash.conf
```

When you trigger an event in the app (such as signing in), you should see some
output in the logstash window.

To explore the data with Kibana, visit http://localhost:5601

#### Using Docker

1. Download, install, and launch [Docker]

1. Set up the Docker image

  ```
  $ bin/setup --docker
  ```

[Docker]: https://docs.docker.com/engine/getstarted/step_one/#step-1-get-docker

More useful Docker commands:

* Start the container: `docker-compose up`
* Stop this running container: `docker-compose stop`
* Stop and delete the containers: `docker-compose down`
* Open a shell in the web container: `docker-compose run --rm web bash`

See the Docker Compose [docs](https://docs.docker.com/compose/install/) for
more information.

[Docker Compose]: (https://docs.docker.com/compose/install/)

### Viewing the app locally

Once it is up and running, the app will be accessible at
`http://localhost:3000/` by default.

Email messages will be visible in MailCatcher at `http://localhost:1080/`.

If you would like to run the application on a different port:

* Change the port number for `mailer_domain_name` and `domain_name` in `config/application.yml`
* Run the app on your desired port like `make run PORT=1234`

If you would like to see the Spanish translations on a particular page, add
`?locale=es` to the end of the URL, such as `http://localhost:3000/?locale=es`.
Currently, you'll need to add `?locale=es` to each URL manually. We are working
on a more robust and user-friendly way to switch between locales.

### Running Tests

Make sure you have [PhantomJS](http://phantomjs.org) installed prior to running
tests. On OS X, PhantomJS can be installed with Homebrew via: `brew install
phantomjs`. For other platforms, refer to the [PhantomJS download
page](http://phantomjs.org/download.html).

To run all the tests:

```
$ make test
```

To run a subset of tests excluding slow tests (such as accessibility specs):
```
$ make fast_test
```

See RSpec [docs](https://relishapp.com/rspec/rspec-core/docs/command-line) for
more information.

JavaScript unit tests will run automatically. However, when authoring JS specs, it is significantly faster to run them in the browser,
as the whole test environment doesn't have to boot up each time. To view JS tests in the browser, visit /teaspoon/default while the application server is running.

Run security scanner

```
$ make brakeman
```

#### User flows

We have an automated tool for generating user flows using real views generated from the application. These specs are excluded from our typical spec run because of the overhead of generating screenshots for each view.

The local instance of the application must be running in order to serve up the assets (eg. `make run`). Then, you can specify where the assets are hosted from and generate the views with:

```
$ RAILS_ASSET_HOST=localhost:3000 rake spec:user_flows
```

Then, visit http://localhost:3000/user_flows in your browser!

### Why 'Upaya'?

"skill in means" https://en.wikipedia.org/wiki/Upaya
