web: WEBPACK_PORT=${WEBPACK_PORT:-3035} bundle exec rackup config.ru --port ${PORT:-3000} --host ${FOREMAN_HOST:-${HOST:-localhost}}
worker: bundle exec good_job start
mailcatcher: mailcatcher -f $([ -n "$HTTPS" ] && echo "--http-ip=0.0.0.0")
js: WEBPACK_PORT=${WEBPACK_PORT:-3035} yarn webpack $([ -n "$HTTPS" ] && echo "--watch" || echo "serve")
css: yarn build:css --watch
