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

run:
	foreman start -p $(PORT)

.PHONY: setup all lint run test check brakeman

normalize_yaml:
	i18n-tasks normalize
	find ./config/locales -type f | xargs ./scripts/normalize-yaml config/country_dialing_codes.yml

optimize_svg:
	find app/assets/images public -name '*.svg' | xargs ./node_modules/.bin/svgo --multipass --config '{"plugins":[{"removeAttrs":{"attrs":"data-name"}}]}'

optimize_assets: optimize_svg

lint_optimized_assets: optimize_assets
	git diff --quiet || (echo "Error: Optimize assets using 'make optimize_assets'"; exit 1)

update_country_dialing_codes:
	bundle exec ./scripts/pinpoint-supported-countries > config/country_dialing_codes.yml

check_asset_strings:
	find ./app/javascript -name "*.js*" | xargs ./scripts/check-assets

generate_deploy_checklist:
	ruby lib/release_management/generate_deploy_checklist.rb
