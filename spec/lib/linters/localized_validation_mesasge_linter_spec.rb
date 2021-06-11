require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../lib/linters/localized_validation_message_linter'

describe RuboCop::Cop::IdentityIdp::LocalizedValidationMessageLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::LocalizedValidationMessageLinter.new(config) }

  context 'plain validation' do
    it 'registers an offense when using static translated string as validation message' do
      expect_offense(<<~RUBY)
        validates :a, presence: { message: I18n.t('error') }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use proc when translating validation message
      RUBY
    end

    it 'registers no offense when using proc as validation message' do
      expect_no_offenses(<<~RUBY)
        validates :a, presence: { message: proc { I18n.t('error') } }
      RUBY
    end
  end

  context 'validation helper' do
    it 'registers an offense when using static translated string as validation message' do
      expect_offense(<<~RUBY)
        validates_presence_of :a, message: I18n.t('error')
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use proc when translating validation message
      RUBY
    end

    it 'registers no offense when using proc as validation message' do
      expect_no_offenses(<<~RUBY)
        validates_presence_of :a, message: proc { I18n.t('error') }
      RUBY
    end
  end
end
