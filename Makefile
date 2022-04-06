# Makefile for building and running the project.
# The purpose of this Makefile is to avoid developers having to remember
# project-specific commands for building, running, etc.  Recipes longer
# than one or two lines should live in script files of their own in the
# bin/ directory.

CONFIG = config/application.yml
HOST ?= localhost
PORT ?= 3000
GZIP_COMMAND ?= gzip
ARTIFACT_DESTINATION_FILE ?= ./tmp/idp.tar.gz

.PHONY: \
	analytics_events \
	brakeman \
	build_artifact \
	check \
	check_asset_strings \
	docker_setup \
	fast_setup \
	fast_test \
	help \
	lint \
	lint_analytics_events \
	lint_country_dialing_codes \
	lint_erb \
	lint_optimized_assets \
	lint_yaml \
	lintfix \
	normalize_yaml \
	optimize_assets \
	optimize_svg \
	run \
	urn \
	setup \
	test \
	update_pinpoint_supported_countries

help: ## Show this help
	@echo "--- Help ---"
	@ruby lib/makefile_help_parser.rb

all: check

setup $(CONFIG): config/application.yml.default ## Runs setup scripts (updates packages, dependencies, databases, etc)
	bin/setup

fast_setup: ## Abbreviated setup script that skips linking some files
	bin/fast_setup

docker_setup: ## Setup script for Docker development
	bin/docker_setup

check: lint test ## Runs lint tests and spec tests

lint: ## Runs all lint tests
	# Ruby
	@echo "--- erb-lint ---"
	make lint_erb
	@echo "--- rubocop ---"
	bundle exec rubocop --parallel
	@echo "--- analytics_events ---"
	make lint_analytics_events
	@echo "--- brakeman ---"
	bundle exec brakeman
	@echo "--- zeitwerk check ---"
	bin/rails zeitwerk:check
	@echo "--- bundler-audit ---"
	bundle exec bundler-audit check --update
	# JavaScript
	@echo "--- yarn audit ---"
	yarn audit --groups dependencies; test $$? -le 7
	@echo "--- eslint ---"
	yarn run lint
	@echo "--- typescript ---"
	yarn run typecheck
	@echo "--- es5-safe ---"
	NODE_ENV=production yarn build && yarn es5-safe
	# Other
	@echo "--- asset check ---"
	make check_asset_strings
	@echo "--- lint yaml ---"
	make lint_yaml
	@echo "--- check assets are optimized ---"
	make lint_optimized_assets
	@echo "--- stylelint ---"
	yarn lint:css

lint_erb: ## Lints ERB files
	bundle exec erblint app/views app/components

lint_yaml: normalize_yaml ## Lints YAML files
	(! git diff --name-only | grep "^config/.*\.yml$$") || (echo "Error: Run 'make normalize_yaml' to normalize YAML"; exit 1)

lintfix: ## Runs rubocop fix
	@echo "--- rubocop fix ---"
	bundle exec rubocop -a

brakeman: ## Runs brakeman
	bundle exec brakeman

public/packs/manifest.json: yarn.lock $(shell find app/javascript -type f) ## Builds JavaScript assets
	yarn build

test: export RAILS_ENV := test
test: $(CONFIG) public/packs/manifest.json ## Runs RSpec and yarn tests
	bundle exec rake parallel:spec && yarn test

fast_test: export RAILS_ENV := test
fast_test: public/packs/manifest.json ## Abbreviated test run, runs RSpec tests without accessibility specs
	bundle exec rspec --exclude-pattern "**/features/accessibility/*_spec.rb"

tmp/$(HOST)-$(PORT).key tmp/$(HOST)-$(PORT).crt: ## Self-signed cert for local HTTPS development
	mkdir -p tmp
	openssl req \
		-newkey rsa:2048 \
		-x509 \
		-sha256 \
		-nodes \
		-days 365 \
		-subj "/C=US/ST=District of Columbia/L=Washington/O=GSA/OU=Login.gov/CN=$(HOST):$(PORT)"  \
		-keyout tmp/$(HOST)-$(PORT).key \
		-out tmp/$(HOST)-$(PORT).crt

run: ## Runs the development server
	foreman start -p $(PORT)

urn:
	@echo "⚱️"
	make run

run-https: tmp/$(HOST)-$(PORT).key tmp/$(HOST)-$(PORT).crt ## Runs the development server with HTTPS
	HTTPS=on FOREMAN_HOST="ssl://$(HOST):$(PORT)?key=tmp/$(HOST)-$(PORT).key&cert=tmp/$(HOST)-$(PORT).crt" foreman start -p $(PORT)

normalize_yaml: ## Normalizes YAML files (alphabetizes keys, fixes line length, smart quotes)
	yarn normalize-yaml .rubocop.yml --disable-sort-keys --disable-smart-punctuation
	find ./config/locales/telephony "./config/locales/telephony*" -type f | xargs yarn normalize-yaml --disable-smart-punctuation
	find ./config/locales -not -path "./config/locales/telephony*" -type f | xargs yarn normalize-yaml \
		config/pinpoint_supported_countries.yml \
		config/pinpoint_overrides.yml \
		config/country_dialing_codes.yml

optimize_svg: ## Optimizes SVG images
	# Without disabling minifyStyles, keyframes are removed (e.g. `app/assets/images/id-card.svg`).
	# See: https://github.com/svg/svgo/issues/888
	find app/assets/images public -name '*.svg' -not -name 'sprite.svg' | xargs ./node_modules/.bin/svgo

optimize_assets: optimize_svg ## Optimizes all assets

lint_optimized_assets: optimize_assets ## Checks that assets are optimized
	(! git diff --name-only | grep "\.svg$$") || (echo "Error: Optimize assets using 'make optimize_assets'"; exit 1)

update_pinpoint_supported_countries: ## Updates list of countries supported by Pinpoint for voice and SMS
	bundle exec ./scripts/pinpoint-supported-countries > config/pinpoint_supported_countries.yml
	bundle exec ./scripts/deep-merge-yaml \
		--comment 'Generated from `make update_pinpoint_supported_countries`' \
		--sources \
		-- \
		config/pinpoint_supported_countries.yml \
		config/pinpoint_overrides.yml \
		> config/country_dialing_codes.yml
	yarn normalize-yaml config/country_dialing_codes.yml config/pinpoint_supported_countries.yml

lint_country_dialing_codes: update_pinpoint_supported_countries ## Checks that countries supported by Pinpoint for voice and SMS are up to date
	(! git diff --name-only | grep config/country_dialing_codes.yml) || (echo "Error: Run 'make update_pinpoint_supported_countries' to update country codes"; exit 1)

check_asset_strings: ## Checks for strings
	find ./app/javascript -name "*.js*" | xargs ./scripts/check-assets

build_artifact $(ARTIFACT_DESTINATION_FILE): ## Builds zipped tar file artifact with IDP source code and Ruby/JS dependencies
	@echo "Building artifact into $(ARTIFACT_DESTINATION_FILE)"
	bundle config set --local cache_all true
	bundle package
	tar \
	  --exclude './config/agencies.yml' \
	  --exclude './config/iaa_gtcs.yml' \
	  --exclude './config/iaa_orders.yml' \
	  --exclude './config/iaa_statuses.yml' \
	  --exclude './config/integration_statuses.yml' \
	  --exclude './config/integrations.yml' \
	  --exclude './config/partner_account_statuses.yml' \
	  --exclude './config/partner_accounts.yml' \
	  --exclude './config/service_providers.yml' \
	  --exclude='./certs/sp' \
	  --exclude='./identity-idp-config' \
	  --exclude='./tmp' \
	  --exclude='./log' \
	  --exclude='./app/javascript/packages/**/node_modules' \
	  --exclude='./node_modules' \
	  --exclude='./geo_data/GeoLite2-City.mmdb' \
	  --exclude='./pwned_passwords/pwned_passwords.txt' \
	  --exclude='./vendor/ruby' \
	  --exclude='./config/application.yml' \
	  -cf - "." | "$(GZIP_COMMAND)" > $(ARTIFACT_DESTINATION_FILE)

analytics_events: public/api/_analytics-events.json ## Generates a JSON file that documents analytics events for events.log

lint_analytics_events: .yardoc # Checks that all methods on AnalyticsEvents are documented
	bundle exec ruby lib/analytics_events_documenter.rb --check $<

public/api/_analytics-events.json: .yardoc .yardoc/objects/root.dat
	mkdir -p public/api
	bundle exec ruby lib/analytics_events_documenter.rb --json $< > $@

.yardoc .yardoc/objects/root.dat: app/services/analytics_events.rb
	bundle exec yard doc \
		--type-tag identity.idp.event_name:"Event Name" \
		--type-tag identity.idp.previous_event_name:"Previous Event Name" \
		--no-output \
		--db $@ \
		-- $<
