# Makefile for building and running the project.
# The purpose of this Makefile is to avoid developers having to remember
# project-specific commands for building, running, etc.  Recipes longer
# than one or two lines should live in script files of their own in the
# bin/ directory.

CONFIG = config/application.yml
PORT ?= 3000

all: check

setup $(CONFIG): config/application.yml.default
	bin/setup

fast_setup:
	bin/fast_setup

docker_setup:
	bin/docker_setup

check: lint test

lint:
	@echo "--- erb-lint ---"
	make lint_erb
	@echo "--- rubocop ---"
	bundle exec rubocop
	@echo "--- fasterer ---"
	bundle exec fasterer
	@echo "--- eslint ---"
	yarn run lint

lint_erb:
	bundle exec erblint app/views

lintfix:
	@echo "--- rubocop fix ---"
	bundle exec rubocop -R -a

brakeman:
	bundle exec brakeman

test: $(CONFIG)
	RAILS_ENV=test bundle exec rake parallel:spec && yarn test

fast_test:
	bundle exec rspec --exclude-pattern "**/features/accessibility/*_spec.rb"

tmp/localhost.key tmp/localhost.crt:
	mkdir -p tmp
	openssl req \
		-newkey rsa:2048 \
		-x509 \
		-sha256 \
		-nodes \
		-days 365 \
		-subj "/C=US/ST=District of Columbia/L=Washington/O=GSA/OU=Login.gov/CN=localhost:3000"  \
		-keyout tmp/localhost.key \
		-out tmp/localhost.crt

run:
	foreman start -p $(PORT)

run-https: tmp/localhost.key tmp/localhost.crt
	rails s -b "ssl://0.0.0.0:3000?key=tmp/localhost.key&cert=tmp/localhost.crt"

.PHONY: setup all lint run test check brakeman

normalize_yaml:
	i18n-tasks normalize
	find ./config/locales -type f | xargs ./scripts/normalize-yaml config/country_dialing_codes.yml

optimize_svg:
	# Without disabling minifyStyles, keyframes are removed (e.g. `app/assets/images/id-card.svg`).
	# See: https://github.com/svg/svgo/issues/888
	find app/assets/images public -name '*.svg' | xargs ./node_modules/.bin/svgo --multipass --disable minifyStyles --config '{"plugins":[{"removeAttrs":{"attrs":"data-name"}}]}'

optimize_assets: optimize_svg

lint_optimized_assets: optimize_assets
	git diff --quiet || (echo "Error: Optimize assets using 'make optimize_assets'"; exit 1)

update_country_dialing_codes:
	bundle exec ./scripts/pinpoint-supported-countries > config/country_dialing_codes.yml

check_asset_strings:
	find ./app/javascript -name "*.js*" | xargs ./scripts/check-assets

generate_deploy_checklist:
	ruby lib/release_management/generate_deploy_checklist.rb
