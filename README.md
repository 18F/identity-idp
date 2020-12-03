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

There are two methods that we recommend for installing for local development. One is container based with Docker, while the other is focused on your local machines installation (advanced). For those who are not familiar with setting up local environments on your machine, we recommend [installing with Docker](#installing-with-docker).

### Installing on your local machine

This installation method is meant for those who are familiar with setting up local development environments on their machines.

1. To start, make sure you have the following dependencies installed and a working development environment:

- Ruby 2.6.5+
- [PostgreSQL](http://www.postgresql.org/download/)
- [Redis 2.8+](http://redis.io/)
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
  and sets up the database. Check out our Makefile commands learn more about what this command does: https://github.com/18F/identity-idp/blob/master/Makefile

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

  To view email messages, Mailcatcher must be running. You can check if it's
  running by visiting http://localhost:1080/. To run Mailcatcher:

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

  [mac-test-passphrase-prompt]: mac-test-passphrase-prompt.png "Mac Test Passphrase Prompt"

  If you would like to preview the translations on a particular page, add
  `?locale=es` to the end of the URL, such as `http://localhost:3000/?locale=es`.
  Currently, you'll need to add `?locale=es` to each URL manually.

#### Viewing outbound SMS messages and phone calls

  To see outbound SMS messages and phone calls, visit `http://localhost:3000/test/telephony`.

#### Adding a custom proofing vendor

    We've added the ability for you to use a custom proofing vendor when developing locally. Here is an example of how you would configure that in your local development environment:

    Check out the private repository for `somevendorname`

    ```
    $ cd vendor
    $ git clone git@github.com:18F/identity-somevendorname-api-client-gem.git somevendorname
    ```

    Add appropriate vendor environment variables to `config/application.yml` -- see a member of the
    login.gov team for credentials and other values.

#### Developing without the internet

  If you want to develop without an internet connection, you can set
  `RAILS_OFFLINE=1` in your environment. This disables the `mx` record
  check on email addresses.

  If you want to measure the app's performance in development, set the
  `rack_mini_profiler` option to `'on'` in `config/application.yml` and
  restart the server. See the [rack_mini_profiler] gem for more details.

  [rack_mini_profiler]: https://github.com/MiniProfiler/rack-mini-profiler

#### Viewing event and log data

To be able to test, visualize and query event and log data, you will need to install the latest versions of the following:

- [Elasticsearch](https://github.com/elastic/elasticsearch)
- [Logstash](https://github.com/elastic/logstash)
- [Kibana](https://github.com/elastic/kibana)

If you are developing on OS X, we recommended installing using Homebrew:

```
brew tap homebrew/services

brew install elasticsearch logstash kibana

brew services start elasticsearch
brew services start kibana
```

You can start `logstash` by running the following command from this repo's root directory:

```
logstash -f logstash.conf
```

When you trigger an event in the app (such as signing in), you should see some
output in the logstash window.

To explore the data with Kibana, visit http://localhost:5601

##### Troubleshooting for Kibana errors

Below are some common errors that we have come across when using Kibana. We've included troubleshooting guidance.

- On the Kibana website: "Your Kibana index is out of date, reset it or use the
X-Pack upgrade assistant."

- In the logstash output:
  ```
  Failed to parse mapping [_default_]: [include_in_all] is not allowed for
  indices created on or after version 6.0.0 as [_all] is deprecated. As a
  replacement, you can use an [copy_to] on mapping fields to create your own
  catch all field.
  ```

Solution, assuming you don't use these services for other apps and are OK with
deleting existing data:

1. Stop all services:
  - Press `ctrl-c` to stop logstash if it's running
  ```console
  brew services stop elasticsearch
  brew services stop kibana
  ```

2. Uninstall everything:
  ```console
  brew uninstall --force elasticsearch
  brew uninstall --force logstash
  brew uninstall --force kibana
  ```
3. Reinstall everything:
  ```console
  brew install elasticsearch logstash kibana
  ```

4. Start the services:
  ```console
  brew services start elasticsearch
  brew services start kibana
  ```

5. Delete the old Kibana index:
  ```console
  curl -XDELETE http://localhost:9200/.kibana
  ```

6. Delete the old logstash template:
  - Visit http://localhost:5601/app/kibana#/dev_tools/console?_g=()
  - Paste `DELETE /_template/logstash` in the box on the left and click
  the green "play" button to run the command

7. Start logstash in a new Terminal tab:
  ```console
  logstash -f logstash.conf
  ```

8. Launch the IdP app and sign in to generate some events. You should see output
in the logstash tab without any errors.

9. Visit http://localhost:5601/ and click "Discover" on the left sidebar. If you
get a warning that no default index pattern exists, copy the last pattern that
appears in the list, which will have the format `logstash-year.month.day`. Paste
it into the "Index pattern" field, then click the "Next step" button.

10. On `Step 2 of 2: Configure settings`, select `@timestamp` from the
`Time Filter field name` dropdown, then click "Create index pattern".

11. Create some more events on the IdP app.

12. Refresh the Kibana website. You should now see new events show up in the
Discover section.

#### Setting up gGeolocation

Login.gov uses MaxMind Geolite2 for geolocation. To test geolocation locally, you will need to add a copy of the Geolite2-City database to the IdP.

The Geolite2-City database can be downloaded from MaxMind's site at [https://dev.maxmind.com/geoip/geoip2/geolite2/](https://dev.maxmind.com/geoip/geoip2/geolite2/).

Download the GeoIP2 Binary and save it at `geo_data/GeoLite2-City.mmdb`.
The app will start using that Geolite2 file for geolocation after restart.

#### Generating IdP user flows

We have an automated tool for generating user flows using real views generated from the application. These specs are excluded from our typical spec run because of the overhead of generating screenshots for each view.

The local instance of the application must be running in order to serve up the assets (eg. `make run`). Then, you can specify where the assets are hosted from and generate the views with:

```
$ RAILS_ASSET_HOST=localhost:3000 rake spec:user_flows
```

Then, visit http://localhost:3000/user_flows in your browser!

The user flows tool also has an export feature which allows you to export everything for the web. You may host these assets with someting like [`simplehttpserver`](https://www.npmjs.com/package/simplehttpserver) or publish to [Federalist](https://federalist.18f.gov/). To publish user flows for Federalist, first make sure the application is running locally (eg. localhost:3000) and run:

```
$ RAILS_ASSET_HOST=localhost:3000 FEDERALIST_PATH=/site/user/repository rake spec:user_flows:web
```

This will output your site to `public/site/user/repository` for quick publishing to [Federalist](https://federalist-docs.18f.gov/pages/using-federalist/). To test compatibility, run `simplehttpserver` from the app's `public` folder and visit `http://localhost:8000/<FEDERALIST PATH>/user_flows` in your browser.

#### Troubleshooting

If you are developing on OS X, and if you receive the following prompt the first time you run the test suite, enter `sekret` as the passphrase:

![alt text][mac-test-passphrase-prompt]

### Installing with Docker

See the [Docker documentation](./docs/Docker.md) to install the IdP as a container.
