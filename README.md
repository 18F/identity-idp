[![Code Climate](https://codeclimate.com/github/18F/identity-idp/badges/gpa.svg)](https://codeclimate.com/github/18F/identity-idp)
[![Test Coverage](https://codeclimate.com/github/18F/identity-idp/badges/coverage.svg)](https://codeclimate.com/github/18F/identity-idp/coverage)

Identity-IdP (Upaya)
=====

The recognition of Identity is an often misunderstood concept in our Democracy.

### Dependencies

- Ruby 2.3.0 (try [rbenv](https://github.com/rbenv/rbenv) or
  [rvm](https://rvm.io/))
- Postgresql (`brew install postgresql` or `apt-get install postgresql`)
- Redis 2.8+

### Mac

The easiest way to install the dependencies on a Mac is to run the
[Laptop](https://github.com/18F/laptop) script. Then, make sure Postgres
and Redis are running:

```
brew services start redis postgres
```

### Getting Started

Run the following command to set up the environment:

    $ bin/setup

This basically runs bundler to install the required gems and sets up the
database.  If that is successful you can run the app server with:

    $ foreman start

### Running Tests

To run all the tests:

    $ bundle exec rspec --require rails_helper

See RSpec [docs](https://relishapp.com/rspec/rspec-core/docs/command-line) for
more information.

##### :construction: VM environment coming soon! :construction:

- Clone the root repository `git clone git@github.com:18F/identity.git`
    - change directory to upaya `cd identity/code/upaya`
- Vagrant up! `vagrant up`
    - Your virtual machine will be downloaded and provisioned. Once your VM is
      booted, the provisioning script will install all necessary dependencies
      and the spec suite will run via `rake spec`. For more information about
      developing in a VM, see our [Wiki entry](#).

## More Information

**Notice:** This project is still in alpha.

### Why 'Upaya'?

"skill in means" https://en.wikipedia.org/wiki/Upaya

## License

[The project is in the public domain](LICENSE.md), and all contributions will
also be released in the public domain. By submitting a pull request, you are
agreeing to waive all rights to your contribution under the terms of the [CC0
Public Domain Dedication](http://creativecommons.org/publicdomain/zero/1.0/).

This project constitutes an original work of the United States Government.
