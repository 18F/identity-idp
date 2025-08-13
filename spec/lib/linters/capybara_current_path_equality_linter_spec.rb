require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/rspec/expect_offense'

require 'rails_helper'
require_relative '../../../lib/linters/capybara_current_path_equality_linter'

RSpec.describe RuboCop::Cop::IdentityIdp::CapybaraCurrentPathEqualityLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::CapybaraCurrentPathEqualityLinter.new(config) }

  it 'registers offense when doing equality check on method/variable' do
    expect_offense(<<~RUBY)
      current_path == a_path
      ^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/CapybaraCurrentPathEqualityLinter: Do not compare equality of `current_path` in Capybara feature specs - instead, use the `have_current_path` matcher on `page` or avoid it entirely
    RUBY
  end

  it 'registers offense when doing inequality check on method/variable' do
    expect_offense(<<~RUBY)
      current_path != a_path
      ^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/CapybaraCurrentPathEqualityLinter: Do not compare equality of `current_path` in Capybara feature specs - instead, use the `have_current_path` matcher on `page` or avoid it entirely
    RUBY
  end

  it 'registers offense when doing equality check on method/variable' do
    expect_offense(<<~RUBY)
      page.current_path == a_path
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/CapybaraCurrentPathEqualityLinter: Do not compare equality of `current_path` in Capybara feature specs - instead, use the `have_current_path` matcher on `page` or avoid it entirely
    RUBY
  end

  it 'registers offense when doing equality check on method/variable with explicit page call' do
    expect_offense(<<~RUBY)
      page.current_path == a_path
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/CapybaraCurrentPathEqualityLinter: Do not compare equality of `current_path` in Capybara feature specs - instead, use the `have_current_path` matcher on `page` or avoid it entirely
    RUBY
  end

  it 'registers offense when doing inequality check on method/variable with explicit page call' do
    expect_offense(<<~RUBY)
      page.current_path != a_path
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/CapybaraCurrentPathEqualityLinter: Do not compare equality of `current_path` in Capybara feature specs - instead, use the `have_current_path` matcher on `page` or avoid it entirely
    RUBY
  end

  it 'registers offense when doing equality check on method/variable on left-hand side' do
    expect_offense(<<~RUBY)
      a_path == current_path
      ^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/CapybaraCurrentPathEqualityLinter: Do not compare equality of `current_path` in Capybara feature specs - instead, use the `have_current_path` matcher on `page` or avoid it entirely
    RUBY
  end

  it 'does not register offense for unrelated comparisons' do
    expect_no_offenses(<<~RUBY)
      1 == 1
    RUBY

    expect_no_offenses(<<~RUBY)
      1 != 1
    RUBY
  end
end
