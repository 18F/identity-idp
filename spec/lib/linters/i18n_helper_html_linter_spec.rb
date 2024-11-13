require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/rspec/expect_offense'

require_relative '../../../lib/linters/i18n_helper_html_linter'

RSpec.describe RuboCop::Cop::IdentityIdp::I18nHelperHtmlLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::I18nHelperHtmlLinter.new(config) }

  it 'registers offense when calling `t` from i18n class with key suffixed by "_html"' do
    expect_offense(<<~RUBY)
      I18n.t('errors.message_html')
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/I18nHelperHtmlLinter: Use the Rails `t` view helper for HTML-safe strings
    RUBY
  end

  it 'registers offense when calling `t` from i18n class with symbol key suffixed by "_html"' do
    expect_offense(<<~RUBY)
      I18n.t(:message_html)
      ^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/I18nHelperHtmlLinter: Use the Rails `t` view helper for HTML-safe strings
    RUBY
  end

  it 'gracefully handles `I18n.t` without arguments' do
    expect_no_offenses(<<~RUBY)
      I18n.t
    RUBY
  end

  it 'gracefully handles `I18n.t` with variable key' do
    expect_no_offenses(<<~RUBY)
      I18n.t(key)
    RUBY
  end

  it 'registers no offense when calling `t` from i18n class with key not suffixed by "_html"' do
    expect_no_offenses(<<~RUBY)
      I18n.t('errors.message')
    RUBY
  end

  it 'registers no offense when calling `t` from Rails view helper' do
    expect_no_offenses(<<~RUBY)
      t('errors.message_html')
    RUBY
  end
end
