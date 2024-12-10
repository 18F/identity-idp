# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require 'capybara/cucumber'
require_relative 'helpers'

Capybara.default_driver = :selenium_chrome
Capybara.server_port = '63629'
