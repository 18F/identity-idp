# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require 'capybara/cucumber'
require_relative 'helpers'
require 'cucumber/rspec/doubles'

Capybara.default_driver = :selenium_chrome

server = Capybara.current_session.server
server_domain = "#{server.host}:#{server.port}"

BeforeAll do
  print 'Bundling JavaScript and stylesheets...'
  system 'yarn concurrently "yarn:build:*" > /dev/null 2>&1'
  puts '✨ Done!'
  Rails.application.config.asset_sources.load_manifest
end

Before do
  allow(IdentityConfig.store).to receive(:domain_name).and_return(server_domain)
  default_url_options = ApplicationController.default_url_options.merge(host: server_domain)
  self.default_url_options = default_url_options
  allow(Rails.application.routes).to receive(:default_url_options).and_return(default_url_options)
end

Before('@id-ipp') do
  allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
  allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)
  allow(IdentityConfig.store).to receive(:proofing_device_profiling).and_return(:enabled)
  allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return('test_org')
end
