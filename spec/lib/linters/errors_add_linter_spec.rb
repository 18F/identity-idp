require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../lib/linters/errors_add_linter'

RSpec.describe RuboCop::Cop::IdentityIdp::ErrorsAddLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::ErrorsAddLinter.new(config) }

  it 'registers an offense when no options are passed' do
    expect_offense(<<~RUBY)
      class MyModel
        def my_method
          errors.add(:number, "is negative")
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/ErrorsAddLinter: Please set a unique key for this error
        end
      end
    RUBY
  end

  it 'registers an offense when no type options are passed' do
    expect_offense(<<~RUBY)
      class MyModel
        def my_method
          errors.add(:number, "is negative", foo: :bar)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/ErrorsAddLinter: Please set a unique key for this error
        end
      end
    RUBY
  end

  it 'does not register an offense for non "errors" add methods' do
    expect_no_offenses(<<~RUBY)
      class MyModel
        def validate
          if number.negative?
            users.add(:name, "test")
          end
        end
      end
    RUBY
  end

  it 'registers no offense when including a symbol "type" error' do
    expect_no_offenses(<<~RUBY)
      class MyModel
        def validate
          if number.negative?
            errors.add(:number, "is negative", type: :is_negative)
          end
        end
      end
    RUBY
  end
end
