require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../lib/linters/url_options_linter'

describe RuboCop::Cop::IdentityIdp::UrlOptionsLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::UrlOptionsLinter.new(config) }

  it 'registers an offense when including Rails url_helpers' do
    expect_offense(<<~RUBY)
      class MyViewModelClass
        include Rails.application.routes.url_helpers
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Please define url_options when including Rails.application.routes.url_helpers

        def my_method
          account_path
        end
      end
    RUBY
  end

  it 'registers no offense when including Rails url_helpers and defining url_options' do
    expect_no_offenses(<<~RUBY)
      class MyViewModelClass
        include Rails.application.routes.url_helpers

        def url_options
          {}
        end
      end
    RUBY
  end

  it 'registers no offense when including Rails url_helpers and defining attr_reader' do
    expect_no_offenses(<<~RUBY)
      class MyViewModelClass
        include Rails.application.routes.url_helpers
        attr_reader :url_options
      end
    RUBY
  end

  it 'registers no offense when including Rails url_helpers and defining attr_accessor' do
    expect_no_offenses(<<~RUBY)
      class MyViewModelClass
        include Rails.application.routes.url_helpers
        attr_accessor :url_options
      end
    RUBY
  end
end
