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
	audit \
	brakeman \
	build_artifact \
	check \
	clobber_db \
	clobber_assets \
	clobber_logs \
	watch_events \
	download_acuant_sdk \
	help \
	lint \
	lint_analytics_events \
	lint_analytics_events_sorted \
	lint_country_dialing_codes \
	lint_database_schema_files \
	lint_erb \
	lint_font_glyphs \
	lint_lockfiles \
	lint_new_typescript_files \
	lint_optimized_assets \
	lint_yaml \
	lint_yarn_workspaces \
	lint_asset_bundle_size \
	lint_readme \
	lint_spec_file_name \
	lintfix \
	normalize_yaml \
	optimize_assets \
	optimize_svg \
	run \
	tidy \
	update \
	urn \
	README.md \
	setup \
	test \
	update_pinpoint_supported_countries

help: ## Show this help
	@echo "--- Help ---"
	@ruby lib/makefile_help_parser.rb

all: check

setup $(CONFIG): config/application.yml.default ## Runs setup scripts (updates packages, dependencies, databases, etc)
	bin/setup

check: lint test ## Runs lint tests and spec tests

lint: ## Runs all lint tests
	# Ruby
	@echo "--- erb-lint ---"
	make lint_erb
	@echo "--- rubocop ---"
	mkdir -p tmp
ifdef JUNIT_OUTPUT
	bundle exec rubocop --parallel --format progress --format junit --out rubocop.xml --display-only-failed --color 2> tmp/rubocop.txt
else
	bundle exec rubocop --parallel --color 2> tmp/rubocop.txt
endif
	awk 'NF {exit 1}' tmp/rubocop.txt || (printf "Error: Unexpected stderr output from Rubocop\n"; cat tmp/rubocop.txt; exit 1)
	@echo "--- analytics_events ---"
	make lint_analytics_events
	make lint_analytics_events_sorted
	@echo "--- brakeman ---"
	make brakeman
	# JavaScript
	@echo "--- eslint ---"
	yarn run lint
	@echo "--- typescript ---"
	yarn run typecheck
	# Other
	@echo "--- lint yaml ---"
	make lint_yaml
	@echo "--- lint font glyphs ---"
	make lint_font_glyphs
	@echo "--- lint Yarn workspaces ---"
	make lint_yarn_workspaces
	@echo "--- lint new TypeScript files ---"
	make lint_new_typescript_files
	@echo "--- lint lockfiles ---"
	make lint_lockfiles
	@echo "--- check assets are optimized ---"
	make lint_optimized_assets
	@echo "--- stylelint ---"
	yarn lint:css
	@echo "--- README.md ---"
	make lint_readme
	@echo "--- lint spec file names ---"
	make lint_spec_file_name
	@echo "--- lint migrations ---"
	make lint_migrations

audit: ## Checks packages for vulnerabilities
	@echo "--- bundler-audit ---"
	bundle exec bundler-audit check --update
	@echo "--- yarn audit ---"
	yarn audit --groups dependencies; test $$? -le 7

lint_erb: ## Lints ERB files
	bundle exec erb_lint app/views app/components

lint_yaml: normalize_yaml ## Lints YAML files
	(! git diff --name-only | grep "^config/.*\.yml") || (echo "Error: Run 'make normalize_yaml' to normalize YAML"; exit 1)

lint_font_glyphs: ## Lints to validate content glyphs match expectations from fonts
	scripts/yaml_characters \
		--exclude-locale=zh \
		--exclude-path=config/locales/telephony \
		--exclude-gem-path=faker \
		--exclude-gem-path=good_job \
		--exclude-gem-path=i18n-tasks \
		--exclude-key-scope=user_mailer \
		> app/assets/fonts/glyphs.txt
	(! git diff --name-only | grep "glyphs\.txt$$") || (echo "Error: New character data found. Follow 'Fonts' instructions in 'docs/frontend.md' to regenerate fonts."; exit 1)

lint_yarn_workspaces: ## Lints Yarn workspace packages
	scripts/validate-workspaces.mjs

lint_asset_bundle_size: ## Lints JavaScript and CSS compiled bundle size
	@# This enforces an asset size budget to ensure that download sizes are reasonable and to protect
	@# against accidentally importing large pieces of third-party libraries. If you're here debugging
	@# a failing build, check to ensure that you've not added more JavaScript or CSS than necessary,
	@# and you have no options to split that from the common bundles. If you need to increase this
	@# budget and accept the fact that this will force end-users to endure longer load times, you
	@# should set the new budget to within a few thousand bytes of the production-compiled size.
	find app/assets/builds/application.css -size -105000c | grep .
	find public/packs/application-*.digested.js -size -5000c | grep .

lint_migrations:
	scripts/migration_check

lint_gemfile_lock: Gemfile Gemfile.lock ## Lints the Gemfile and its lockfile
	@bundle check
	@git diff-index --quiet HEAD Gemfile.lock || (echo "Error: There are uncommitted changes after running 'bundle install'"; exit 1)

lint_yarn_lock: package.json yarn.lock ## Lints the package.json and its lockfile
	@yarn install --ignore-scripts
	@(! git diff --name-only | grep yarn.lock) || (echo "Error: There are uncommitted changes after running 'yarn install'"; exit 1)
	@yarn yarn-deduplicate
	@(! git diff --name-only | grep yarn.lock) || (echo "Error: There are duplicate JS dependencies that were removed after running 'yarn yarn-deduplicate'"; exit 1)

lint_lockfiles: lint_gemfile_lock lint_yarn_lock ## Lints to ensure lockfiles are in sync

lint_new_typescript_files:
	scripts/enforce-typescript-files.mjs

lint_readme: README.md ## Lints README.md
	(! git diff --name-only | grep "^README.md$$") || (echo "Error: Run 'make README.md' to regenerate the README.md"; exit 1)

lint_spec_file_name:
	@find spec/*/** -type f \
		-name '*.rb' \
		-and -not -name '*_spec.rb' \
		-and -not -path 'spec/factories/*' \
		-and -not -path 'spec/support/*' \
		-and -not -path '*/previews/*' \
		-exec false {} + \
		-exec echo "Error: Spec files named incorrectly, should end in '_spec.rb':" {} +
	@find app/javascript/packages -type f \
		"(" -name '*spec.js' -or -name '*spec.ts' -or -name '*spec.jsx' -or -name '*spec.tsx' ")" \
		-and -not \
		"(" -name '*.spec.js' -or -name '*.spec.ts' -or -name '*.spec.jsx' -or -name '*.spec.tsx' ")" \
		-exec false {} + \
		-exec echo "Error: Spec files named incorrectly, should end in '.spec.(js|ts|jsx|tsx)':" {} +

lintfix: ## Try to automatically fix any Ruby, ERB, JavaScript, YAML, or CSS lint errors
	@echo "--- rubocop fix ---"
	bundle exec rubocop -a
	@echo "--- erb_lint fix ---"
	bundle exec erb_lint app/views app/components -a
	@echo "--- eslint fix ---"
	yarn lint --fix
	@echo "--- stylelint fix ---"
	yarn lint:css --fix
	@echo "--- normalize yaml ---"
	make normalize_yaml

brakeman: ## Runs brakeman code security check
	(bundle exec brakeman) || (echo "Error: update code as needed to remove security issues. For known exceptions already in brakeman.ignore, use brakeman to interactively update exceptions."; exit 1)

public/packs/manifest.json: yarn.lock $(shell find app/javascript -type f) ## Builds JavaScript assets
	yarn build:js

browsers.json: yarn.lock .browserslistrc ## Generates browsers.json browser support file
	yarn generate-browsers-json

test: export RAILS_ENV := test
test: $(CONFIG) ## Runs RSpec and yarn tests
	bundle exec rspec && yarn test

test_serial: export RAILS_ENV := test
test_serial: $(CONFIG) ## Runs RSpec and yarn tests serially
	bundle exec rake spec && yarn test

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

run: browsers.json ## Runs the development server
	foreman start -p $(PORT)

urn:
	@echo "⚱️"
	make run

run-https: tmp/$(HOST)-$(PORT).key tmp/$(HOST)-$(PORT).crt ## Runs the development server with HTTPS
	HTTPS=on FOREMAN_HOST="ssl://$(HOST):$(PORT)?key=tmp/$(HOST)-$(PORT).key&cert=tmp/$(HOST)-$(PORT).crt" foreman start -p $(PORT)

normalize_yaml: ## Normalizes YAML files (alphabetizes keys, fixes line length, smart quotes)
	yarn normalize-yaml .rubocop.yml --disable-sort-keys --disable-smart-punctuation
	find ./config/locales/transliterate -type f -name '*.yml' -exec yarn normalize-yaml --disable-sort-keys --disable-smart-punctuation {} \;
	yarn normalize-yaml --disable-smart-punctuation --ignore-key-sort development,production,test config/application.yml.default
	find ./config/locales/telephony -type f -name '*.yml' | xargs yarn normalize-yaml --disable-smart-punctuation
	find ./config/locales -not \( -path "./config/locales/telephony*" -o -path "./config/locales/transliterate/*" \) -type f -name '*.yml' | \
	xargs yarn normalize-yaml \
		config/pinpoint_supported_countries.yml \
		config/pinpoint_overrides.yml \
		config/country_dialing_codes.yml

optimize_svg: ## Optimizes SVG images
	# Exclusions:
	# - `login-icon-bimi.svg` is hand-optimized and includes required metadata that would be stripped by SVGO
	find app/assets/images public -name '*.svg' -not -name 'login-icon-bimi.svg' -not -name 'selfie-capture-accept-help.svg' | xargs ./node_modules/.bin/svgo

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

lint_database_schema_files: ## Checks that database schema files have not changed
	(! git diff --name-only | grep db/schema.rb) || (echo "Error: db/schema.rb does not match after running migrations"; exit 1)
	(! git diff --name-only | grep db/worker_jobs_schema.rb) || (echo "Error: db/worker_jobs_schema.rb does not match after running migrations"; exit 1)

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

lint_analytics_events: .yardoc ## Checks that all methods on AnalyticsEvents are documented
	bundle exec ruby lib/analytics_events_documenter.rb --class-name="AnalyticsEvents" --check $<

lint_analytics_events_sorted:
	@test "$(shell grep '^  def ' app/services/analytics_events.rb)" = "$(shell grep '^  def ' app/services/analytics_events.rb | sort)" \
		|| (echo '\033[1;31mError: methods in analytics_events.rb are not sorted alphabetically\033[0m' && exit 1)

public/api/_analytics-events.json: .yardoc .yardoc/objects/root.dat
	mkdir -p public/api
	bundle exec ruby lib/analytics_events_documenter.rb --class-name="AnalyticsEvents" --json $< > $@

.yardoc .yardoc/objects/root.dat: app/services/analytics_events.rb
	bundle exec yard doc \
		--fail-on-warning \
		--type-tag identity.idp.previous_event_name:"Previous Event Name" \
		--no-output \
		--db $@ \
		-- $^

update: ## Update dependencies, useful after a git pull
	bundle install
	yarn install
	bundle exec rails db:migrate

README.md: docs/ ## Generates README.md based on the contents of the docs directory
	bundle exec ruby scripts/generate_readme.rb --docs-dir $< > $@

download_acuant_sdk: ## Downloads the most recent Acuant SDK release from Github
	@scripts/download_acuant_sdk.sh

clobber_db: ## Resets the database for make setup
	bin/rake db:create
	bin/rake db:environment:set
	bin/rake db:reset
	bin/rake db:environment:set
	bin/rake dev:prime

clobber_assets: ## Removes (clobbers) assets
	bin/rake assets:clobber
	RAILS_ENV=test bin/rake assets:clobber

clobber_logs: ## Purges logs and tmp/
	rm -f log/*
	rm -rf tmp/cache/*
	rm -rf tmp/encrypted_doc_storage
	rm -rf tmp/letter_opener
	rm -rf tmp/mails

watch_events: ## Prints events logging as they happen
	@tail -F -n0 log/events.log | jq "select(.name | test(\".*$$EVENT_NAME.*\"; \"i\")) | ."

tidy: clobber_assets clobber_logs ## Remove assets, logs, and unused gems, but leave DB alone
	bundle clean
