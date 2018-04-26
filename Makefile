# Makefile for building and running the project.
# The purpose of this Makefile is to avoid developers having to remember
# project-specific commands for building, running, etc.  Recipes longer
# than one or two lines should live in script files of their own in the
# bin/ directory.

CONFIG = config/application.yml
PORT ?= 3000

all: check

setup $(CONFIG): config/application.yml.example
	bin/setup

fast_setup:
	bin/fast_setup

check: lint test

lint:
	@echo "--- rubocop ---"
	bundle exec rubocop -R
	@echo "--- slim-lint ---"
	bundle exec slim-lint app/views
	@echo "--- reek ---"
	bundle exec reek
	@echo "--- fasterer ---"
	bundle exec fasterer
	@echo "--- eslint ---"
	node_modules/.bin/eslint app spec

lintfix:
	@echo "--- rubocop fix ---"
	bundle exec rubocop -R -a
	@echo "--- reek fix ---"
	bundle exec reek -t

brakeman:
	bundle exec brakeman

test: $(CONFIG)
	bundle exec rspec && yarn test

fast_test:
	bundle exec rspec --exclude-pattern "**/features/accessibility/*_spec.rb"

run:
	foreman start -p $(PORT)

run-dev:
	foreman start -p $(PORT) -f Procfile_dev

load_test: $(CONFIG)
	bin/load_test $(type)

.PHONY: setup all lint run test check brakeman

normalize_yaml:
	find ./config/locales -type f | xargs ./scripts/normalize-yaml
