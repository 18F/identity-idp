require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../lib/linters/translation_linter'

describe RuboCop::Cop::IdentityIdp::TranslationLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::TranslationLinter.new(config) }

  it 'registers offense when calling translate method' do
    expect_offense(<<~RUBY)
      t('foo.bar.baz')
      ^^^^^^^^^^^^^^^^ Translation is not allowed in this file
    RUBY
  end
end
