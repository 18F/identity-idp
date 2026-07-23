# Troubleshooting Local Development

## I am receiving errors when running `$ make setup`

If this command returns errors, you may need to install the dependencies first, outside of the Makefile:
```
$ bundle install
$ npm install
```

If you receive the an error `connection to server at "127.0.0.1", port 5432 failed: Connection refused`, check that you have Postgres installed and running:
```
brew install postgresql
brew services start postgres
```

## I am receiving errors when creating the development and test databases

If you receive the following error (where _whoami_ == _your username_):

`psql: error: connection to server on socket "/tmp/.s.PGSQL.5432" failed: FATAL:  database "<whoami>" does not exist`

Running the following command first, may solve the issue:
```
$ createdb `whoami`
```

## I am receiving errors when running `$ make test`

### Errors related to running specs in _parallel_
`$ make test` runs specs in _parallel_ which could potentially return errors. Running specs _serially_ may fix the problem; to run specs _serially_:
```
$ make test_serial
```

### Errors related to Capybara in feature tests
Feature specs drive a real browser via Selenium. You do **not** need to install chromedriver manually: Selenium 4's built-in [Selenium Manager](https://www.selenium.dev/documentation/selenium_manager/) automatically downloads a chromedriver that matches your installed version of Chrome the first time a JavaScript spec runs. This requires Chrome to be installed and network access on first run.

If you prefer to use a specific chromedriver binary, point Selenium at it by setting `CHROMEDRIVER_PATH` or placing it on your `PATH`. On macOS a manually downloaded chromedriver may be blocked by Gatekeeper ("Apple could not verify..."); clear the quarantine attribute with `xattr -c /path/to/chromedriver` before use.

If JavaScript feature specs fail intermittently on navigation-timing assertions (for example, `expected "/sign_up/enter_email" to equal "/sign_up/verify_email"`), it is likely because the default Capybara wait time is intentionally `0` locally (see [#8013](https://github.com/18F/identity-idp/pull/8013)). Run the specs with the same wait time CI uses:
```
$ CAPYBARA_WAIT_TIME_SECONDS=5 bundle exec rspec spec/features/...
```

### Errors related to _too many open files_
You may receive connection errors similar to the following:

`Failed to open TCP connection to 127.0.0.1:9515 (Too many open files - socket(2) for "127.0.0.1" port 9515)`

You are encountering you OS's [limits on allowed file descriptors](https://wilsonmar.github.io/maximum-limits/). Check the limits with both:
* `ulimit -n`
* `launchctl limit maxfiles`

Try this to increase the user limit:
```
$ ulimit -Sn 65536 && make test
```
To set this _permanently_, add the following to your `~/.zshrc` or `~/.bash_profile` file, depending on your shell:
```
ulimit -Sn 65536
```

If you are running MacOS, you may find it is not taking your revised ulimit seriously. [You must insist.](https://medium.com/mindful-technology/too-many-open-files-limit-ulimit-on-mac-os-x-add0f1bfddde) Run this command to edit a property list file:
```
sudo nano /Library/LaunchDaemons/limit.maxfiles.plist
```
Paste the following contents into the text editor:
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
          "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>limit.maxfiles</string>
    <key>ProgramArguments</key>
    <array>
      <string>launchctl</string>
      <string>limit</string>
      <string>maxfiles</string>
      <string>524288</string>
      <string>524288</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ServiceIPC</key>
    <false/>
  </dict>
</plist>

```
Use Control+X to save the file.

Restart your Mac to cause the .plist to take effect. Check the limits again and you should see both `ulimit -n` and `launchctl limit maxfiles` return a limit of 524288.

### Errors relating to OpenSSL versions

If you get this error during test runs:
```
     Failure/Error: JWT::JWK.import(certs_response[:keys].first).public_key
     OpenSSL::PKey::PKeyError:
       rsa#set_key= is incompatible with OpenSSL 3.0
```

This problem has happened when Ruby was built and linked against the
wrong version of OpenSSL.

The procedure we have found that fixes the problem is to rebuild Ruby,
linked against the correct version of OpenSSL, then remove and
reinstall all of your gems.

These instructions have been used successfully for environments
managed using `asdf`, `chruby` and `rbenv`. Details for each are
below.

If you are using another Ruby version manager, the section on
`ruby-build` is likely your best starting point. Please add your
experience and any useful information to this document.

### Details
- These instructions assume you're on a Mac; if not, you will have to
  work out the equivalent directions based on these.

- As of this writing, the correct Ruby version for login.gov is 3.2.0.
  Use whatever the current version is.

#### One spec which shows the problem:

`spec/features/openid_connect/openid_connect_spec.rb`

The problem looks like:
```
1) OpenID Connect receives an ID token with a kid that matches the certs endpoint
     Failure/Error: JWT::JWK.import(certs_response[:keys].first).public_key
     OpenSSL::PKey::PKeyError:
       rsa#set_key= is incompatible with OpenSSL 3.0
```

#### Finding out where you have openssl 1.1 installed

`brew --prefix openssl@1.1`

If not present, run `brew install openssl@1.1`

#### Version manager specifics
Most version managers simply require that the correct version of Ruby
be installed, usually using `ruby-build`.

##### Rebuilding Ruby using `asdf`
`asdf` uses `ruby-build` under the covers, but supplies some
configuration of its own, so we must use `asdf` to (re-)install Ruby.

Remove the existing Ruby version, if present:

`asdf uninstall ruby 3.2.0`

And re-install, using the correct OpenSSL installation:

`RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)" asdf install ruby 3.2.0`

##### Rebuilding Ruby using `chruby`
Use the `ruby-build` instructions; `chruby` doesn't require anything special.

##### Rebuilding Ruby using `rbenv`
Use the `ruby-build` instructions; `rbenv` doesn't require anything special, although use `~/.rbenv/versions` for the install location, not `~/.rubies`.

##### Rebuilding Ruby using `ruby-build`
Make sure ruby-build is up to date

`brew upgrade ruby-build`

And then rebuild Ruby (this assumes your Rubies are in ~/.rubies)

`RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)" ruby-build 3.2.0 ~/.rubies/3.2.0`

#### Exiting your shell
After your Ruby is built, exit your shell and open a new one, to clear caches.

#### Removing all of your gems

`gem uninstall -aIx`

#### Reinstalling your gems

`bundle install`

