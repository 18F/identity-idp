upaya
=====

The recognition of Identity is an often misunderstood concept in our Democracy.


### Dependencies

- Ruby 2.3.0 (try [rbenv](https://github.com/rbenv/rbenv) or
  [rvm](https://rvm.io/))
- Bundler (`gem install bundler`)
- postgresql (`brew install postgresql` or `apt-get install postgresql`)

### Mac

- [Vagrant](https://www.vagrantup.com/downloads.html)
- [Virtualbox](https://www.virtualbox.org/wiki/Downloads) or [VMware Fusion](https://www.vmware.com/products/fusion)

Or, try the [Laptop](https://github.com/18F/laptop) script for setting up a
slick development environment.

### Getting Started

Run the following command to set up the environment:

    $ bin/setup

This basically runs bundler to install the required gems and sets up the
database.  If that is successful you can run the app server with:

    $ bin/rails server

### Running Tests

To run all the tests:

    $ bundle exec rspec --require rails_helper

See RSpec [docs](https://relishapp.com/rspec/rspec-core/docs/command-line) for
more information.

### Docker

 * Install the [Docker Toolbox](https://www.docker.com/products/docker-toolbox)
 * Ensure your docker VM is running: `docker-machine start default`
 * Fire up postgres: `docker run --name postgres -e POSTGRES_PASSWORD=$(openssl rand -hex 16) -d postgres`
 * Build your development container: `docker build -t upaya .`
 * Initialize your database: `docker run --link postgres --rm upaya rake db:setup`
 * Run your app: `docker run --link postgres --rm upaya`
 * Run your app, mounting your local repo in the container: `docker run --link postgres --rm -v $(pwd):/upaya`
 * Run a shell in that container instead: `docker run --link postgres --rm -ti -v $(pwd):/upaya bash`

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

### Why 'upaya'?

"skill in means" https://en.wikipedia.org/wiki/Upaya

## License

[The project is in the public domain](LICENSE.md), and all contributions will
also be released in the public domain. By submitting a pull request, you are
agreeing to waive all rights to your contribution under the terms of the [CC0
Public Domain Dedication](http://creativecommons.org/publicdomain/zero/1.0/).

This project constitutes an original work of the United States Government.