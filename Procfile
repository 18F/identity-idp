web: bundle exec rackup config.ru --port ${PORT:-3000} --host ${HOST:-localhost}
worker: bundle exec good_job start
job_runs: bundle exec rake job_runs:run
mailcatcher: mailcatcher -f
webpacker: ./bin/webpack-dev-server
