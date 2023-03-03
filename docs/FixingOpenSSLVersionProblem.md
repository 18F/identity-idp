# This document describes a recurrent problem with OpenSSL and some of our tests
The problem appears to manifests when Ruby was built and linked against
the wrong version of OpenSSL. In summary, the procedure we have found
that fixes the problem is to rebuild Ruby, linked against the correct
version of OpenSSL, then remove and reinstall all of your gems.

# Details
- These instructions assume you're on a Mac; if not, you will have to
  work out the equivilent directions based on these.

- As of this writing, the correct Ruby version for login.gov is 3.2.0.
  Use whatever the current version is.

## One spec which shows the problem:

`spec/features/openid_connect/openid_connect_spec.rb`

The problem looks like:
```
1) OpenID Connect receives an ID token with a kid that matches the certs endpooint
     Failure/Error: JWT::JWK.import(certs_response[:keys].first).public_key
     OpenSSL::PKey::PKeyError:
       rsa#set_key= is incompatible with OpenSSL 3.0
```

## Finding out where you have openssl 1.1 installed

Run the command `brew --prefix openssl@1.1`

If not present, run `brew install openssl@1.1`

## Rebuilding Ruby using asdf

Remove the existing Ruby version, if present:
`asdf uninstall ruby 3.2.0`

And re-install, using the correct OpenSSL installation:
`RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)" asdf install ruby 3.2.0`

## Rebuilding Ruby using ruby-build

Make sure ruby-build is up to date
`brew upgrade ruby-build`

And then rebuild Ruby (this assumes your Rubies are in ~/.rubies)
`RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)" ruby-build 3.2.0 ~/.rubies/3.2.0`

## Exiting your shell
After your Ruby is built, exit your shell and open a new one, to clear caches.

## Removing all of your gems

`gem uninstall -aIx`

## Reinstalling your gems

`bundle install`
