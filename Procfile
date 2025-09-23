web: WEBPACK_PORT=${WEBPACK_PORT:-3035} bundle exec rackup config.ru --port ${PORT:-3000} --host ${FOREMAN_HOST:-${HOST:-localhost}}
worker: bundle exec good_job start
js: WEBPACK_PORT=${WEBPACK_PORT:-3035} ORIGIN_PORT=${ORIGIN_PORT:-3000} npm exec webpack -- --watch
css: npm run build:css -- --watch
