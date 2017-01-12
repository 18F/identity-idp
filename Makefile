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

check: lint test

lint: $(CONFIG)
	@echo "--- rubocop ---"
	bundle exec rubocop -R
	@echo "--- slim-lint ---"
	bundle exec slim-lint app/views
	@echo "--- reek ---"
	bundle exec reek

brakeman:
	bundle exec brakeman

test: $(CONFIG)
	bundle exec rspec && bundle exec teaspoon

fast_test: $(CONFIG)
	bundle exec rspec --exclude-pattern "**/features/accessibility/*_spec.rb"

run: $(CONFIG)
	foreman start -p $(PORT)

.PHONY: setup all lint run test check brakeman
