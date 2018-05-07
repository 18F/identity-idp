Identity-IdP (Upaya)
====================

[![Build Status](https://circleci.com/gh/18F/identity-idp.svg?style=svg)](https://circleci.com/gh/18F/identity-idp)
[![Code Climate](https://api.codeclimate.com/v1/badges/e78d453f7cbcac64a664/maintainability)](https://codeclimate.com/github/18F/identity-idp/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/e78d453f7cbcac64a664/test_coverage)](https://codeclimate.com/github/18F/identity-idp/test_coverage)
[![security](https://hakiri.io/github/18F/identity-idp/master.svg)](https://hakiri.io/github/18F/identity-idp/master)

A Identity Management System powering login.gov.

### Local development

#### Dependencies

- Ruby 2.3
- [Postgresql](http://www.postgresql.org/download/)
- [Redis 2.8+](http://redis.io/)
- [Node.js v8.x.x](https://nodejs.org)

#### Setting up and running the app

1. Make sure you have a working development environment with all the
  [dependencies](#dependencies) installed. On OS X, the easiest way
  to set up a development environment is by running our [Laptop]
  script. The script will install all of this project's dependencies.

  If using rbenv, you may need to alias your specific installed ruby version to the more generic version found in the `.ruby-version` file. To do this, use [`rbenv-aliases`](https://github.com/tpope/rbenv-aliases):

  ```
  git clone git://github.com/tpope/rbenv-aliases.git "$(rbenv root)/plugins/rbenv-aliases" # install rbenv-aliases per its documentation

  rbenv alias 2.3 2.3.5 # create the version alias
  ```

2. Make sure Postgres and Redis are running.

  For example, if you've installed the laptop script on OS X, you can start the services like this:

  ```
  $ brew services start redis
  $ brew services start postgresql
  ```

3. Create the development and test databases:

  ```
  $ psql -c "CREATE DATABASE upaya_development;"
  $ psql -c "CREATE DATABASE upaya_test;"
  ```

4. Run the following command to set up the environment:

  ```
  $ make setup
  ```

  This command copies sample configuration files, installs required gems
  and sets up the database.

5. Run the app server with:

  ```
  $ make run
  ```

Before making any commits, you'll also need to run `overcommit --sign.`
This verifies that the commit hooks defined in our `.overcommit.yml` file are
the ones we expect. Each change to the `.overcommit.yml` file, including the initial install
performed in the setup script, will necessitate a new signature.

For more information, see [overcommit](https://github.com/brigade/overcommit)


If you want to develop without an internet connection, you can set
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

To view email messages, Mailcatcher must be running. You can check if it's
running by visiting http://localhost:1080/. To run Mailcatcher:

```
$ mailcatcher
```

If you would like to run the application on a different port:

* Change the port number for `mailer_domain_name` and `domain_name` in `config/application.yml`
* Run the app on your desired port like `make run PORT=1234`

If you would like to see the Spanish translations on a particular page, add
`?locale=es` to the end of the URL, such as `http://localhost:3000/?locale=es`.
Currently, you'll need to add `?locale=es` to each URL manually. We are working
on a more robust and user-friendly way to switch between locales.

### Running Tests

To run all the tests:

```
$ make test
```

To run a subset of tests excluding slow tests (such as accessibility specs):
```
$ make fast_test
```

If you are on a mac, if you receive the following prompt the first time you run the test suite, enter `sekret` as the passphrase:

![alt text][mac-test-passphrase-prompt]

See RSpec [docs](https://relishapp.com/rspec/rspec-core/docs/command-line) for
more information.

JavaScript unit tests run using the mocha test runner. Check out the
[mocha documentation](https://mochajs.org/) for more details.

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

##### Exporting

The user flows tool also has an export feature which allows you to export everything for the web. You may host these assets with someting like [`simplehttpserver`](https://www.npmjs.com/package/simplehttpserver) or publish to [Federalist](https://federalist.18f.gov/). To publish user flows for Federalist, first make sure the application is running locally (eg. localhost:3000) and run:

```
$ RAILS_ASSET_HOST=localhost:3000 FEDERALIST_PATH=/site/user/repository rake spec:user_flows:web
```

This will output your site to `public/site/user/repository` for quick publishing to [Federalist](https://federalist-docs.18f.gov/pages/using-federalist/). To test compatibility, run `simplehttpserver` from the app's `public` folder and visit `http://localhost:8000/<FEDERALIST PATH>/user_flows` in your browser.

### Load testing

We provide some [Locust.io] Python scripts you can run to test how the
app responds to load. You'll need to have Python and `pyenv-virtualenvwrapper`
installed on your machine. If you're on a Mac, the easiest way to set up Python
and `pyenv-virtualenvwrapper` is to run the [laptop script].

Next, you'll need to set the following values in your local `application.yml`:

```
disable_email_sending: 'true'
enable_load_testing_mode: 'true'
telephony_disabled: 'true'
```

Then, run the app with `make run`, and in a new Terminal tab or window, run:
```
make load_test type=create_account
```
This will simulate 3 concurrent users going through the entire account creation
flow and then signing out. To change the number of concurrent users, number of
requests, and the rate at which users are created, modify the `-c`,
`-n`, and `-r` Locust parameters in `bin/load_test`. Run `locust --help` for
more details.

By default, the test will target the host running at `http://localhost:3000`.
To change the target host, set the `TARGET_HOST` environment variable.
For example:

```
TARGET_HOST=https://awesome.loadtesting.com make load_test type=create_account
```

[Locust.io]: http://locust.io/
[laptop script]: https://github.com/18F/laptop

### Proofing vendors

Some proofing vendor code is located in private Github repositories because of NDAs. You can still use it
in your local development environment if you have access to the private repository.

Example:

#### Check out the private repository for `somevendorname`

```
$ cd vendor
$ git clone git@github.com:18F/identity-somevendorname-api-client-gem.git somevendorname
```

#### Add the vendor configuration

Add appropriate vendor environment variables to `config/application.yml` -- see a member of the
login.gov team for credentials and other values.

### Why 'Upaya'?

"skill in means" https://en.wikipedia.org/wiki/Upaya

### Managing translation files

To help us handle extra newlines and make sure we wrap lines consistently, we have a script called `./scripts/normalize-yaml` that helps format YAML consistently. After importing translations (or making changes to the *.yml files with strings, run this for the IDP app:

```
$ make normalize_yaml
```

[mac-test-passphrase-prompt]: mac-test-passphrase-prompt.png "Mac Test Passphrase Prompt"
