# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require 'capybara/cucumber'
require_relative 'helpers'
require 'cucumber/rspec/doubles'

Capybara.default_driver = :selenium_chrome

server = Capybara.current_session.server
server_domain = "#{server.host}:#{server.port}"

Before do
  allow(IdentityConfig.store).to receive(:domain_name).and_return(server_domain)
end
