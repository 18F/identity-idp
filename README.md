Login.gov Identity Provider (IdP)
=================================

Login.gov is the public's one account for government. Use one account and password for secure, private access to participating government agencies.

This repository contains the core code base and documentation for the identity management system powering secure.login.gov.

## Contributing to this code base

Thank you for your interest in contributing to the Login.gov IdP! For complete instructions on how to contribute code, please read through our [CONTRIBUTING.md](CONTRIBUTING.md) documentation.

## Creating your local development environment

### Installing on your local machine

This installation method is meant for those who are familiar with setting up local development environments on their machines. If you encounter errors, see the [Troubleshooting](#troubleshooting) section at the bottom of this README.

We recommend using [Homebrew](https://brew.sh/), [rbenv](https://github.com/rbenv/rbenv), [nvm](https://github.com/nvm-sh/nvm) or other version management tooling to install the below dependencies; while we don't anticipate changing these frequently, this will ensure that you will be able to easily switch to different versions as needed.

#### Dependencies
1. To start, make sure you have the following dependencies installed and a working development environment:

- Ruby ~> 3.0.4
- [PostgreSQL](http://www.postgresql.org/download/)
- [Redis 5+](http://redis.io/)
- [Node.js v16](https://nodejs.org)
- [Yarn](https://yarnpkg.com/en/)
- [chromedriver](https://formulae.brew.sh/cask/chromedriver)

2. You will need to install openssl version 1.1:

- Run `brew install openssl@1.1`

3. Test that you have Postgres and Redis running.

  For example, if you've installed with Homebrew, you can start the services like this:

  ```
  $ brew services start redis
  $ brew services start postgresql
  ```

  To confirm the services are running properly, run:
  ```
  $ brew services list
  ```

4. Run the following command to set up your local environment:

  ```
  $ make setup
  ```

  This command copies sample configuration files, installs required gems
  and sets up the database. Check out our Makefile commands to learn more about what this command does: https://github.com/18F/identity-idp/blob/main/Makefile

  Note: If you didn't explicitly install `openssl@1.1` in Step 2 above and you use a M1 Mac, you may see an error on this step. Homebrew works differently on a M1 Mac, so specifying the version is necessary for the make script to work, but may still work on x86.

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

  Check out our Makefile commands learn more about how you can customize this command to run specific tests using rspec: https://github.com/18F/identity-idp/blob/main/Makefile#L41

  To test a specific spec file with rspec, you may need to add the following configuration to `/config/application.yml` so the tests do not crash:
  ```
  test:
    rack_timeout_service_timeout_seconds: 9_999_999_999
  ```

##### Showing the Browser

  By default, the acceptance specs use a headless browser for speed. If you want to see the browser, run the specs with `SHOW_BROWSER=true` environment variable:

  ```
  $ SHOW_BROWSER=true bundle exec rspec spec/features/
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

  In local development, the application does not deliver real email messages. Instead, we use a tool called [Mailcatcher](https://github.com/sj26/mailcatcher) to capture all messages.

  - To view email messages which would have been sent, visit http://localhost:1080/ while the application is running.
  - To view email templates with placeholder values, visit http://localhost:3000/rails/mailers/ to see a list of template previews.

#### Translations

  Login.gov translates the IdP into English, French and Spanish. To help us handle extra newlines and make sure we wrap lines consistently, we have a script that helps format YAML consistently. After importing translations (or making changes to the `*.yml` files with strings, run this for the IdP app:

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

#### Testing on a mobile device or in a virtual machine

By default, the application binds to `localhost`. To test on a network device or within a virtual machine, you can bind to `0.0.0.0` instead, using the following instructions:

1. Determine your computer's network IP address. On macOS, you can find this in the "Network" system settings, shown under the "Status: Connected" label. This often takes the format of `192.168.1.x` or `10.0.0.x`.
2. In `config/application.yml`, add `domain_name` and `mailer_domain_name` keys under `development`, like so:
   ```yaml
   development:
     domain_name: <your-local-ip>:3000
     mailer_domain_name: <your-local-ip>:3000
   ```
   replacing `<your-local-ip>` with the address you found in Step 1
3. Start the server using the command `HOST=0.0.0.0 make run`
4. Assuming that your phone or virtual machine computer is connected on the same network, visit the application using the domain name configured in the second step (for example, `http://192.168.1.131:3000`).

#### Testing the application over HTTPS

```
$ make run-https
```

Or, to run on a different host:

```
$ HOST=0.0.0.0 make run-https
```

The `run-https` Makefile target will automatically provision a self-signed certificate and start the built-in Rails server.

You can now navigate to https://localhost:3000/ .

It's likely that you'll be prompted with a screen with warnings about an unsafe connection. This is normal. Find the option on the screen to bypass the warning. It may be hidden under an "Advanced" toggle button. In Chrome, you may not see an option to bypass this screen. In these situations, type the letters `thisisunsafe` while the screen is active, and you will be redirected automatically.

### Installing with Docker

There was an initial attempt to dockerize the IDP but it is currently deprecated, mostly non-functional, and not maintained. There is ongoing work to make the IDP more [12 Factor](https://12factor.net/) compliant which will eventually lead to better support for containerization.

If you'd like to work with the previous implementation see the [Docker documentation](./docs/Docker.md) to install the IdP as a container.

### Troubleshooting
#### I am receiving errors when running `$ make setup`

If this command returns errors, you may need to install the dependencies first, outside of the Makefile:
```
$ bundle install
$ yarn install
```

#### I am receiving errors related to Capybara in feature tests
You may need to install _chromedriver_ or your chromedriver may be the wrong version (`$ which chromedriver && chromedriver --version`).

chromedriver can be installed using [Homebrew](https://formulae.brew.sh/cask/chromedriver) or [direct download](https://chromedriver.chromium.org/downloads). The version of chromedriver should correspond to the version of Chrome you have installed `(Chrome > About Google Chrome)`; if installing via Homebrew, make sure the versions match up. (`brew reinstall` will move to the latest version.)

If `chromedriver -v` does not work you may have to [allow it](https://stackoverflow.com/questions/60362018/macos-catalinav-10-15-3-error-chromedriver-cannot-be-opened-because-the-de) with `xattr`.

#### I am receiving errors when creating the development and test databases

If you receive the following error (where _whoami_ == _your username_):

`psql: error: connection to server on socket "/tmp/.s.PGSQL.5432" failed: FATAL:  database "<whoami>" does not exist`

Running the following command first, may solve the issue:
```
$ createdb `whoami`
```

#### I am receiving errors when running `$ make test`

##### Errors related to running specs in _parallel_
`$ make test` runs specs in _parallel_ which could potentially return errors. Running specs _serially_ may fix the problem; to run specs _serially_:
```
$ make test_serial
```

##### Errors related to too many _open files_
You may receive connection errors similar to the following:

`Failed to open TCP connection to 127.0.0.1:9515 (Too many open files - socket(2) for "127.0.0.1" port 9515)`

Running the following, _prior_ to running tests, may solve the problem:
```
$ ulimit -Sn 65536 && make test
```
To set this _permanently_, add the following to your `~/.zshrc` or `~/.bash_profile` file, depending on your shell:
```
ulimit -Sn 65536
```
