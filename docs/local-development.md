# Local Development

## Installing on your local machine

This installation method is meant for those who are familiar with setting up local development environments on their machines. If you encounter errors, see [Troubleshooting](./troubleshooting.md).

We recommend using [Homebrew](https://brew.sh/), [rbenv](https://github.com/rbenv/rbenv), [nvm](https://github.com/nvm-sh/nvm) or other version management tooling to install the below dependencies; while we don't anticipate changing these frequently, this will ensure that you will be able to easily switch to different versions as needed.

### Dependencies

Installing the packages differs slightly if you're on a macOS or a different OS.

If using macOS:

1. Install [rbenv](https://github.com/rbenv/rbenv) (lets you install and switch between different versions of Ruby)
1. Install Ruby. Choose the version [in the `.ruby-version` file](../.ruby-version)
1. Skip to the [set up local environment section](#set-up-local-environment). Your other dependencies will be installed in that step.

If not using macOS:

1. To start, make sure you have the following dependencies installed and a working development environment:

    - [rbenv](https://github.com/rbenv/rbenv) (lets you install and switch between different versions of Ruby)
    - Ruby. Choose the version [in the `.ruby-version` file](../.ruby-version)
    - [PostgreSQL](http://www.postgresql.org/download/)
    - [PostGIS](https://postgis.net/documentation/getting_started/#installing-postgis)
        - Note: if you run into errors installing `postgis` or creating the database, check [the troubleshooting docs](./troubleshooting.md#errors-related-to-the-databse).
    - [Redis 7+](http://redis.io/)
    - [Node.js v18](https://nodejs.org)
    - [Yarn](https://yarnpkg.com/en/)
    - [chromedriver](https://formulae.brew.sh/cask/chromedriver)

1. You will need to install openssl version 1.1:

    - Run `brew install openssl@1.1`

1. Test that you have Postgres and Redis running.

1. Continue to the [set up local environment section](#set-up-local-environment).

### Set up local environment

1. Run the following command to set up your local environment:

    ```
    $ make setup
    ```

    This command copies sample configuration files, installs required gems and brew packages (if using macOS), and sets up the database. Check out our [Makefile commands](../Makefile) to learn more about what this command does.

1. Now that you have you have everything installed, you can run the following command to start your local server:

    ```
    $ make run
    ```

    You should now be able to go to open up your favorite browser, go to `localhost:3000` and see your local development environment running.

### Simulating a partner authentication request

Typically, a person who uses Login.gov will arrive from a partner application, and their experience
on Login.gov will be customized to incorporate the name and logo of the partner. They will also be
asked to consent to share their information with the partner before being sent back.

To simulate a true end-to-end user experience, you can either...

- Use the built-in test controller for SAML logins at http://localhost:3000/test/saml/login
- Or, run a sample partner application, which is configured by default to run with your local IdP instance:
   - OIDC: https://github.com/18F/identity-oidc-sinatra
      - Runs at http://localhost:9292/
   - SAML: https://github.com/18F/identity-saml-sinatra
      - Runs at http://localhost:4567/

Running the sample application requires a few additional steps, but can be useful if you want to
test the experience of a user being redirected to an external site, or if you want to configure
different options of the authentication request, such as AAL or IAL.

### Running tests locally

  Login.gov uses the following tools for our testing:

  - [RSpec](https://relishapp.com/rspec/rspec-core/docs/command-line)
  - [Mocha documentation](https://mochajs.org/)

  To run our full test suite locally, use the following command:

  ```
  $ make test
  ```

  Use the following command to run a subset of our test suite, excluding slower tests:

  ```
  $ make fast_test
  ```

  Check out our Makefile commands and learn more about how you can customize this command to run specific tests using rspec: https://github.com/18F/identity-idp/blob/main/Makefile#L41

  To test a specific spec file with rspec, you may need to add the following configuration to `/config/application.yml` so the tests do not crash:
  ```
  test:
    rack_timeout_service_timeout_seconds: 9_999_999_999
  ```

#### Showing the Browser

  By default, the acceptance specs use a headless browser for speed. If you want to see the browser, run the specs with `SHOW_BROWSER=true` environment variable:

  ```
  $ SHOW_BROWSER=true bundle exec rspec spec/features/
  ```

#### Skipping asset compilation in feature tests

To ensure that tests are run using the latest source code, JavaScript-enabled feature specs will
compile all JavaScript and stylesheets in local development. This can be time-consuming if you're
repeatedly running the same tests, so you can choose to skip the build by passing the
`SKIP_BUILD=true` environment variable:

```
$ SKIP_BUILD=true bundle exec rspec spec/features
```

Since the automatic build is meant to act as a safeguard to prevent stale assets from being used,
disabling it will mean you're responsible for running the build any time JavaScript or Sass source
files are changed. You can do this by running `yarn build` for JavaScript, or `yarn build:css` for
stylesheets.

### Viewing email messages

  In local development, the application does not deliver real email messages. Instead, we use a tool
  called [letter_opener](https://github.com/ryanb/letter_opener) to display messages.

#### Disabling letter opener new window behavior

  Letter opener will open each outgoing email in a new browser window or tab. In cases where this
  will be annoying the application also supports writing outgoing emails to a file. To write emails
  to a file add the following config to the `development` group in `config/application.yml`:

  ```
  development:
    development_mailer_deliver_method: file
  ```

  After restarting the app emails will be written to the `tmp/mails` folder.

#### Email template previews

  To view email templates with placeholder values, visit http://localhost:3000/rails/mailers/ to see a list of template previews.

### Translations

  Login.gov translates the IdP into English, French and Spanish. To help us handle extra newlines and make sure we wrap lines consistently, we have a script that helps format YAML consistently. After importing translations (or making changes to the `*.yml` files with strings), run this for the IdP app:

  ```
  $ make normalize_yaml
  ```

  If you would like to preview the translations on a particular page, use the Language dropdown in the footer of the website. To manually override a locale, add the locale as the first segment of the URL:
  - http://localhost:3000 becomes http://localhost:3000/es
  - http://localhost:3000/sign_up/enter_email becomes http://localhost:3000/es/sign_up/enter_email

### Viewing outbound SMS messages and phone calls

  To see outbound SMS messages and phone calls, visit `http://localhost:3000/test/telephony`.

### Viewing RISC push notifications

To view [RISC Security Events](https://developers.login.gov/security-events/) push notifications delivered by the application, visit http://localhost:3000/test/push_notification.

### Setting up Geolocation

Login.gov uses MaxMind Geolite2 for geolocation. To test geolocation locally, you will need to add a copy of the Geolite2-City database to the IdP.

The Geolite2-City database can be downloaded from MaxMind's site at [https://dev.maxmind.com/geoip/geoip2/geolite2/](https://dev.maxmind.com/geoip/geoip2/geolite2/).

Download the GeoIP2 Binary and save it at `geo_data/GeoLite2-City.mmdb`.
The app will start using that Geolite2 file for geolocation after restart.

### Testing in a virtual machine

By default, the application binds to `localhost`. To test on a local network device or within a virtual machine, you can bind to `0.0.0.0`. Before development, use the following instructions based on your machine's operating system.

1. From the "Network" tab on:

  * Monterey and below

    Once on "Network" system settings, your IP address is shown under "Status: Connected" label.

  * Ventura

    Select "Wi-Fi" or "Ethernet". This option will change based on how you are connected to the internet. From there, click "Details".

    **IP addresses often take the format of `192.168.1.x` or `10.0.0.x`.**

2. In `config/application.yml`, add `domain_name` and `mailer_domain_name` keys under `development`, like so:
   ```yaml
   development:
     domain_name: <your-local-ip>:3000
     mailer_domain_name: <your-local-ip>:3000
   ```
   replacing `<your-local-ip>` with the address you found in Step 1
3. Start the server using the command `HOST=0.0.0.0 make run`
4. From on the same network, visit the application using the domain name configured in the second step (for example, `http://192.168.1.131:3000`).

### Testing on a mobile device

[Moble device instructions are here](mobile.md)

### Testing the application over HTTPS

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

## Installing with Docker

There was an initial attempt to dockerize the IDP but it is currently deprecated, mostly non-functional, and not maintained. There is ongoing work to make the IDP more [12 Factor](https://12factor.net/) compliant which will eventually lead to better support for containerization.

If you'd like to work with the previous implementation see the [Docker documentation](./docs/Docker.md) to install the IdP as a container.

## Linting

Run `make lint` to look for errors; `make lintfix` can repair some linting errors.

## Configuration variables

Default configuration values &mdash; like feature flags, timeout settings, and third-party connection details &mdash; are found in [`config/application.yml.default`](config/application.yml/default). From these defaults the file `config/application.yml` is created during `make setup` for use during local development. [See the handbook](https://handbook.login.gov/articles/appdev-secrets-configuration.html).

In deployed environments, configuration values are managed with the [app-s3-secret](https://github.com/18F/identity-devops/blob/main/bin/app-s3-secret) script. [See the handbook](https://handbook.login.gov/articles/devops-scripts.html#app-s3-secret).

## Running jobs

We run background jobs / workers with ActiveJob and GoodJob. You shouldn't normally have to start it manually because `make run` runs [the `Procfile`](Procfile), which handles it. The manual command is: `bundle exec good_job start`

Processes can be configured to run via async jobs or synchronously using flags such as `deliver_mail_async` in [application.yml](config/application.yml.default)
