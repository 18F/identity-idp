web: WEBPACK_PORT=${WEBPACK_PORT:-3035} bundle exec rackup config.ru --port ${PORT:-3000} --host ${HOST:-localhost}
worker: bundle exec good_job start
mailcatcher: mailcatcher -f
js: WEBPACK_PORT=${WEBPACK_PORT:-3035} yarn webpack serve
