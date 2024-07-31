$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'saml_idp/version'

Gem::Specification.new do |s|
  s.name = 'saml_idp'
  s.version = SamlIdp::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Jon Phenow', 'Peter Karman']
  s.email = 'peter.karman@gsa.gov'
  s.homepage = 'http://github.com/18F/saml_idp'
  s.summary = 'SAML Identity Provider in Ruby'
  s.description = 'SAML IdP (Identity Provider) library in ruby'
  s.files = Dir.glob('app/**/*') + Dir.glob('lib/**/*') + [
    'LICENSE',
    'README.md',
    'Gemfile',
    'saml_idp.gemspec',
  ]
  s.license = 'LICENSE'
  s.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']
  s.rdoc_options = ['--charset=UTF-8']

  s.required_ruby_version = '>= 3.1.0'

  s.add_dependency('activesupport')
  s.add_dependency('builder')
  s.add_dependency('faraday')
  s.add_dependency('nokogiri', '>= 1.10.2')
  s.add_dependency('pkcs11')

  s.add_development_dependency('capybara', '~> 3.40')
  s.add_development_dependency('listen')
  s.add_development_dependency 'pry-byebug'
  s.add_development_dependency('rails', '~> 7.1')
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rubocop', '1.62.0'
  s.add_development_dependency 'rubocop-rails', '2.9'
  s.add_development_dependency 'rubocop-rspec'
  s.add_development_dependency 'ruby-saml', '~> 1.16.0'
  s.add_development_dependency 'simplecov', '~> 0.22.0'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency('timecop')
  s.add_development_dependency('xmlenc', '>= 0.7.1')
  s.metadata['rubygems_mfa_required'] = 'true'
end
