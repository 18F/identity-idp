require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../lib/linters/analytics_event_name_linter'

RSpec.describe RuboCop::Cop::IdentityIdp::AnalyticsEventNameLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::AnalyticsEventNameLinter.new(config) }

  it 'registers an offense when event name does not match method name' do
    expect_offense(<<~RUBY)
      module AnalyticsEvents
        def my_method
          track_event(:not_my_method)
                      ^^^^^^^^^^^^^^ IdentityIdp/AnalyticsEventNameLinter: Event name must match the method name, expected `:my_method`
        end
      end
    RUBY
  end

  it 'does not register an offense when event name matches method name' do
    expect_no_offenses(<<~RUBY)
      module AnalyticsEvents
        def my_method
          track_event(:my_method)
        end
      end
    RUBY
  end

  it 'does not register an offense for an exempted legacy event name' do
    expect_no_offenses(<<~RUBY)
      module AnalyticsEvents
        def idv_back_image_added
          track_event('Frontend: IdV: back image added')
        end
      end
    RUBY
  end
end
