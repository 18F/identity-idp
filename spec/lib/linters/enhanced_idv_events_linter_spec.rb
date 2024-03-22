require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/rspec/expect_offense'

require_relative '../../../lib/linters/enhanced_idv_events_linter'

RSpec.describe RuboCop::Cop::IdentityIdp::EnhancedIdvEventsLinter do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  let(:config) { RuboCop::Config.new }
  let(:cop) { RuboCop::Cop::IdentityIdp::EnhancedIdvEventsLinter.new(config) }
  let(:check_param_docs) { false }

  before do
    if !check_param_docs
      # Most of these tests don't involve the @param doc linter, so
      # unwire it here.
      allow(cop).to receive(:check_arg_has_docs).and_return(nil)
    end

    allow(cop).to receive(:extra_args_for_method).and_return(
      [
        :proofing_components,
      ],
    )
  end

  it 'registers an offense when an idv_ is missing proofing_components' do
    expect_offense(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method
        ^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: Method is missing proofing_components argument.
          track_event(:idv_my_method)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: proofing_components is missing from track_event call.
        end
      end
    RUBY
  end

  it 'registers an offense when an idv_ method is missing proofing_components with **extra' do
    expect_offense(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(**extra)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: Method is missing proofing_components argument.
          track_event(:idv_my_method, **extra)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: proofing_components is missing from track_event call.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(proofing_components: nil, **extra)
          track_event(:idv_my_method, proofing_components: proofing_components, **extra)
        end
      end
    RUBY
  end

  it 'registers offense when idv_ method missing proofing_components with **extra and other args' do
    expect_offense(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(other:, **extra)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: Method is missing proofing_components argument.
          track_event(:idv_my_method, other: other, **extra)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: proofing_components is missing from track_event call.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(other:, proofing_components: nil, **extra)
          track_event(:idv_my_method, other: other, proofing_components: proofing_components, **extra)
        end
      end
    RUBY
  end

  it 'does not register an offense when an proofing_components present on track_event call' do
    expect_no_offenses(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(proofing_components: nil, **extra)
          track_event(:idv_my_method, proofing_components: proofing_components, **extra)
        end
      end
    RUBY
  end

  it 'registers an offense when an proofing_components is missing from track_event call' do
    expect_offense(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(proofing_components: nil, **extra)
          track_event(:idv_my_method, **extra)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: proofing_components is missing from track_event call.
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(proofing_components: nil, **extra)
          track_event(:idv_my_method, proofing_components: proofing_components, **extra)
        end
      end
    RUBY
  end

  it 'can put the track_event arg on its own line if needed' do
    expect_offense(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(proofing_components: nil, **extra)
          track_event(
          ^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: proofing_components is missing from track_event call.
            :idv_my_method,
            **extra,
          )
        end    
      end
    RUBY
    expect_correction(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(proofing_components: nil, **extra)
          track_event(
            :idv_my_method,
            proofing_components: proofing_components,
            **extra,
          )
        end    
      end
    RUBY
  end

  it 'can put the method arg on its own line if needed' do
    expect_offense(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(
        ^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: Method is missing proofing_components argument.
          foo:,
          bar:,
          **extra
        )
          track_event(:idv_my_method, proofing_components: proofing_components, **extra)
        end    
      end
    RUBY
    expect_correction(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(
          foo:,
          bar:,
          proofing_components: nil,
          **extra
        )
          track_event(:idv_my_method, proofing_components: proofing_components, **extra)
        end    
      end
    RUBY
  end

  it 'handles track_event calls with a hash arg' do
    expect_no_offenses(<<~RUBY)
        module AnalyticsEvents
          def idv_my_method(
            type:,
            proofing_components: nil,
            limiter_expires_at: nil,
            remaining_submit_attempts: nil,
            **extra
          )
            track_event(
              'IdV: phone error visited',
              {
                type: type,
                proofing_components: proofing_components,
                limiter_expires_at: limiter_expires_at,
                remaining_submit_attempts: remaining_submit_attempts,
                **extra,
              }.compact,
            )
        end
      end
    RUBY
  end

  it 'handles track_event calls without **extra' do
    expect_offense(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(
        ^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: Method is missing proofing_components argument.
          type:,
          limiter_expires_at: nil,
          remaining_submit_attempts: nil,
          **_extra
        )
          track_event(
          ^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: proofing_components is missing from track_event call.
            'IdV: phone error visited',
            type: type,
            limiter_expires_at: limiter_expires_at,
            remaining_submit_attempts: remaining_submit_attempts,
          )
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method(
          type:,
          limiter_expires_at: nil,
          remaining_submit_attempts: nil,
          proofing_components: nil,
          **_extra
        )
          track_event(
            'IdV: phone error visited',
            type: type,
            limiter_expires_at: limiter_expires_at,
            remaining_submit_attempts: remaining_submit_attempts,
            proofing_components: proofing_components,
          )
        end
      end
    RUBY
  end

  it 'breaks track_event calls across lines' do
    allow(cop).to receive(:max_line_length).and_return(100)
    expect_offense(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method_that_is_really_really_long(**extra)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: Method is missing proofing_components argument.
          track_event(:idv_my_method_that_is_really_really_long, **extra)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: proofing_components is missing from track_event call.
        end    
      end
    RUBY

    expect_correction(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method_that_is_really_really_long(proofing_components: nil, **extra)
          track_event(
            :idv_my_method_that_is_really_really_long,
            proofing_components: proofing_components,
            **extra
          )
        end    
      end
    RUBY
  end

  it 'can break method definitions across lines' do
    allow(cop).to receive(:max_line_length).and_return(100)

    expect_offense(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method_that_is_really_really_long(step_name:, remaining_submit_attempts:, **extra)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: Method is missing proofing_components argument.
          track_event(
          ^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: proofing_components is missing from track_event call.
            :idv_my_method_that_is_really_really_long,
            step_name: step_name,
            remaining_submit_attempts: remaining_submit_attempts,
            **extra,
          )
        end
      end
    RUBY

    expect_correction(<<~RUBY)
      module AnalyticsEvents
        def idv_my_method_that_is_really_really_long(
          step_name:,
          remaining_submit_attempts:,
          proofing_components: nil,
          **extra
        )
          track_event(
            :idv_my_method_that_is_really_really_long,
            step_name: step_name,
            remaining_submit_attempts: remaining_submit_attempts,
            proofing_components: proofing_components,
            **extra,
          )
        end
      end
    RUBY
  end

  describe 'parameter documentation' do
    let(:check_param_docs) { true }

    it 'can add parameter documentation for proofing_components' do
      expect_offense(<<~RUBY)
        module AnalyticsEvents
          def idv_my_method(other:, **extra)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: Method is missing proofing_components argument.
            track_event(:idv_my_method, other: other, **extra)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: proofing_components is missing from track_event call.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        module AnalyticsEvents
          # @param [Object] proofing_components TODO: Write doc comment
          def idv_my_method(other:, proofing_components: nil, **extra)
            track_event(:idv_my_method, other: other, proofing_components: proofing_components, **extra)
          end
        end
      RUBY
    end

    it 'can add parameter documentation for proofing_components with param docs already there' do
      expect_offense(<<~RUBY)
        module AnalyticsEvents
          # @param [String] other Some param
          # Logs an event for my method
          def idv_my_method(other:, **extra)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: Method is missing proofing_components argument.
            track_event(:idv_my_method, other: other, **extra)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: proofing_components is missing from track_event call.
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        module AnalyticsEvents
          # @param [String] other Some param
          # @param [Object] proofing_components TODO: Write doc comment
          # Logs an event for my method
          def idv_my_method(other:, proofing_components: nil, **extra)
            track_event(:idv_my_method, other: other, proofing_components: proofing_components, **extra)
          end
        end
      RUBY
    end
  end

  describe 'profile_history' do
    context 'method should not receive profile_history' do
      it 'registers no offense' do
        expect_no_offenses(<<~RUBY)
          module AnalyticsEvents
            def idv_final(proofing_components:, **extra)
              track_event(:idv_final, proofing_components: proofing_components, **extra)
            end    
          end
        RUBY
      end
    end

    context 'method should receive profile_history' do
      before do
        allow(cop).to receive(:extra_args_for_method).and_return(
          %i[
            proofing_components
            profile_history
          ],
        )
      end

      it 'registers offence when method that should receive profile_history does not' do
        expect_offense(<<~RUBY)
          module AnalyticsEvents
            def idv_final(proofing_components:, **extra)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: Method is missing profile_history argument.
              track_event(:idv_final, proofing_components: proofing_components, **extra)
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ IdentityIdp/EnhancedIdvEventsLinter: profile_history is missing from track_event call.
            end    
          end
        RUBY
      end
    end
  end
end
