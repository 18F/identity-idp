require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
$LOAD_PATH.unshift File.dirname(__FILE__)

warn("Running Specs under Ruby Version #{RUBY_VERSION}")

require 'rails_app/config/environment'

require 'rspec'
require 'capybara/rspec'
require 'capybara/rails'

require 'ruby-saml'
require 'saml_idp'
require 'timecop'

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each { |f| require f }

RSpec.configure do |config|
  config.mock_with :rspec
  config.order = 'random'

  config.include CertificateHelpers
  config.include SamlRequestMacros
  config.include SecurityHelpers

  config.before do
    SamlIdp.configure do |c|
      c.attributes = {
        emailAddress: {
          name: 'email-address',
          getter: ->(_p) { 'foo@example.com' },
        },
      }

      c.name_id.formats = {
        email_address: ->(_p) { 'foo@example.com' },
      }
    end
  end
end

Capybara.default_host = 'https://app.example.com'
