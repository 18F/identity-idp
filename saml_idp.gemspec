# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path("../lib", __FILE__)
require "saml_idp/version"

Gem::Specification.new do |s|
  s.name = %q{saml_idp}
  s.version = SamlIdp::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Jon Phenow", 'Peter Karman']
  s.email = %q{peter.karman@gsa.gov}
  s.homepage = %q{http://github.com/18F/saml_idp}
  s.summary = %q{SAML Indentity Provider in Ruby}
  s.description = %q{SAML IdP (Identity Provider) library in ruby}
  s.date = Time.now.utc.strftime("%Y-%m-%d")
  s.files = Dir.glob("app/**/*") + Dir.glob("lib/**/*") + [
     "LICENSE",
     "README.md",
     "Gemfile",
     "saml_idp.gemspec"
  ]
  s.license = "LICENSE"
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.rdoc_options = ["--charset=UTF-8"]

  s.post_install_message = <<-INST
If you're just recently updating saml_idp - please be aware we've changed the default
certificate. See the PR and a description of why we've done this here:
https://github.com/sportngin/saml_idp/pull/29

If you just need to see the certificate `bundle open saml_idp` and go to
`lib/saml_idp/default.rb`

Similarly, please see the README about certificates - you should avoid using the
defaults in a Production environment. Post any issues you to github.

** New in Version 0.3.0 **

Encrypted Assertions require the xmlenc gem. See the example in the Controller
section of the README.
  INST

  s.add_dependency('activesupport')
  s.add_dependency('uuid')
  s.add_dependency('builder')
  s.add_dependency('httparty')
  s.add_dependency('nokogiri', '>= 1.6.2')

  s.add_development_dependency "rake"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "rspec"
  s.add_development_dependency "ruby-saml", "~> 1.4.1"
  s.add_development_dependency("rails", "~> 4.2")
  s.add_development_dependency("capybara")
  s.add_development_dependency("timecop")
  s.add_development_dependency("xmlenc", ">= 0.6.4")
end

