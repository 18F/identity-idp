require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/rspec/expect_offense'

require 'rails_helper'
require_relative '../../../lib/linters/capybara_current_url_expect_linter'

RSpec.describe RuboCop::Cop::IdentityIdp::CapybaraCurrentUrlExpectLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::CapybaraCurrentUrlExpectLinter.new(config) }

  it 'registers offense when expecting current_url with eq' do
    expect_offense(<<~RUBY)
      expect(current_url).to eq root_url
                          ^^ IdentityIdp/CapybaraCurrentUrlExpectLinter: Do not set an RSpec expectation on `current_url` in Capybara feature specs - instead, use the `have_current_path` matcher on `page`
    RUBY
  end

  it 'registers an offense with negation' do
    expect_offense(<<~RUBY)
      expect(current_url).not_to eq root_url
                          ^^^^^^ IdentityIdp/CapybaraCurrentUrlExpectLinter: Do not set an RSpec expectation on `current_url` in Capybara feature specs - instead, use the `have_current_path` matcher on `page`
    RUBY
  end

  it 'registers offense when calling expecting current_url with include' do
    expect_offense(<<~RUBY)
      expect(current_url).to include('/')
                          ^^ IdentityIdp/CapybaraCurrentUrlExpectLinter: Do not set an RSpec expectation on `current_url` in Capybara feature specs - instead, use the `have_current_path` matcher on `page`
    RUBY
  end

  it 'registers offense when calling expecting current_url with start_with' do
    expect_offense(<<~RUBY)
      expect(current_url).to start_with('/')
                          ^^ IdentityIdp/CapybaraCurrentUrlExpectLinter: Do not set an RSpec expectation on `current_url` in Capybara feature specs - instead, use the `have_current_path` matcher on `page`
    RUBY
  end

  it 'registers offense when calling expecting current_url with match regular expression' do
    expect_offense(<<~RUBY)
      expect(current_url).to match /localhost/
                          ^^ IdentityIdp/CapybaraCurrentUrlExpectLinter: Do not set an RSpec expectation on `current_url` in Capybara feature specs - instead, use the `have_current_path` matcher on `page`
    RUBY
  end

  it 'registers offense when calling expecting current_url with match string' do
    expect_offense(<<~RUBY)
      expect(current_url).to match 'localhost'
                          ^^ IdentityIdp/CapybaraCurrentUrlExpectLinter: Do not set an RSpec expectation on `current_url` in Capybara feature specs - instead, use the `have_current_path` matcher on `page`
    RUBY
  end

  it 'does not register offense for correct usage' do
    expect_no_offenses(<<~RUBY)
      expect(page).to have_current_path(root_path)
    RUBY

    expect_no_offenses(<<~RUBY)
      expect(page).to have_current_path('http://localhost:4001', url: true)
    RUBY
  end

  it 'does not register offense for unrelated expectations' do
    expect_no_offenses(<<~RUBY)
      expect(user.created_at).to eq 3
    RUBY
  end
end
