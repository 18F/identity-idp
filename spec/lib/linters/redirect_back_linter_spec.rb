require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../lib/linters/redirect_back_linter'

RSpec.describe RuboCop::Cop::IdentityIdp::RedirectBackLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::RedirectBackLinter.new(config) }

  it 'registers offenses when calling redirect_back with no arguments' do
    expect_offense(<<~RUBY)
      redirect_back
      ^^^^^^^^^^^^^ IdentityIdp/RedirectBackLinter: Please set a fallback_location and the allow_other_host parameter to false
    RUBY
  end

  it 'registers offenses when calling redirect_back with only fallback location' do
    expect_offense(<<~RUBY)
      redirect_back fallback_location: '/'
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/RedirectBackLinter: Please set a fallback_location and the allow_other_host parameter to false
    RUBY
  end

  it 'registers offenses when calling redirect_back with only allow_other_host set to false' do
    expect_offense(<<~RUBY)
      redirect_back allow_other_host: false
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/RedirectBackLinter: Please set a fallback_location and the allow_other_host parameter to false
    RUBY
  end

  it 'registers no offense when including Rails url_helpers and defining url_options' do
    expect_no_offenses(<<~RUBY)
      redirect_back fallback_location: '/', allow_other_host: false
    RUBY
  end
end
