# encoding: utf-8
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'
$LOAD_PATH.unshift File.dirname(__FILE__)

STDERR.puts("Running Specs under Ruby Version #{RUBY_VERSION}")

require 'rspec'
require 'ruby-saml'
require 'ruby-saml-idp'

RSpec.configure do |c|
  c.mock_with :rspec
end

