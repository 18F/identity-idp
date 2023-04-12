# Troubleshooting

#### I am receiving errors when running `$ make setup`

If this command returns errors, you may need to install the dependencies first, outside of the Makefile:
```
$ bundle install
$ yarn install
```

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

##### Errors related to Capybara in feature tests
You may need to install _chromedriver_ or your chromedriver may be the wrong version (`$ which chromedriver && chromedriver --version`).

chromedriver can be installed using [Homebrew](https://formulae.brew.sh/cask/chromedriver) or [direct download](https://chromedriver.chromium.org/downloads). The version of chromedriver should correspond to the version of Chrome you have installed `(Chrome > About Google Chrome)`; if installing via Homebrew, make sure the versions match up. After your system recieves an automatic Chrome browser update you may have to upgrade (or reinstall) chromedriver.

If `chromedriver -v` does not work you may have to [allow it](https://stackoverflow.com/questions/60362018/macos-catalinav-10-15-3-error-chromedriver-cannot-be-opened-because-the-de) with `xattr`.

##### Errors related to _too many open files_
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

##### Errors related to _sassc_

If you are getting the error:
```
LoadError: cannot load such file -- sassc
```
Try `make run` for a short time, then use Ctrl+C to kill it

##### Errors relating to OpenSSL versions

If you get this error during test runs:
```
     Failure/Error: JWT::JWK.import(certs_response[:keys].first).public_key
     OpenSSL::PKey::PKeyError:
       rsa#set_key= is incompatible with OpenSSL 3.0
```
See [this document](docs/FixingOpenSSLVersionProblem.md) for how to fix it.

