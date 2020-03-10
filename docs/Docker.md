# Docker

## Run the app locally with Docker

1. Download, install, and launch [Docker](https://www.docker.com/products/docker-desktop). You may need to increase memory resources in Docker above the defaults to avoid timeouts.

1. Build the __Rails base__, __Rails development__, and __production IDP__ images: `bin/docker_build`

1. Build the development Docker containers using __Rails base__ and __Rails development__ images: `docker-compose build`

1. Run `make docker_setup` to copy configuration files and bootstrap the database.

1. Start the Docker containers `docker-compose up` and `open http://localhost:3000`

Please note that the `docker_setup` script will destroy and re-create configuration files that were previously symlinked.  See the script source for more info.

If `Gemfile` or `package.json` change, you'll need to `docker-compose build` again to install those new dependencies. 

## More useful Docker commands:

* Run migrations: `docker-compose run --rm web bundle exec rails db:migrate`
* Force the images to re-build: `docker-compose build --no-cache`. You might have to do this if a "regular build" doesn't seem to correctly install new dependencies.
* Stop the containers: `docker-compose stop`
* Stop and remove the containers (`-v` removes Volumes, which includes Postgres data): `docker-compose down`
* Open a shell in a one-off web container: `docker-compose run --rm web bash`
* Open a shell in the running web container: `docker-compose exec web bash`
* Open a shell in the running web container as root: `docker-compose exec --user=root web bash`
* Open a psql shell in the running db container: `docker-compose exec db psql -U postgres`
* `docker system prune` to remove dangling images and free up disk space

## Running Tests in Docker

* After Docker is set up you can run the entire suite with `docker-compose run web bundle exec rspec`. This takes a while.
* You can run a one-off test with `docker-compose run web bundle exec rspec spec/file.rb`
* If the cluster is already running you can run the test on those containers using `exec` instead of `run`: `docker-compose exec web bundle exec rspec spec/file.rb`