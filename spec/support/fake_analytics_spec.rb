require 'rails_helper'

RSpec.describe FakeAnalytics do
  subject(:analytics) { FakeAnalytics.new }

  describe '#have_logged_event' do
    context 'no arguments' do
      let(:track_event) { -> { analytics.track_event :my_event } }
      let(:code_under_test) { -> { expect(analytics).to have_logged_event } }

      it 'raises if event was not logged' do
        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
          assert_error_messages_equal(err, <<~MESSAGE)
            Expected that FakeAnalytics would have received event nil
            with nil.
  
            Events received:
            {}
          MESSAGE
        end
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 2x' do
        track_event.call
        track_event.call

        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    context 'event name only' do
      let(:track_event) { -> { analytics.track_event :my_event } }
      let(:code_under_test) { -> { expect(analytics).to have_logged_event(:my_event) } }

      it 'raises if no event has been logged' do
        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received event :my_event
              with nil.

              Events received:
              {}
            MESSAGE
          end
      end

      it 'raises if another type of event has been logged' do
        analytics.track_event(:my_other_event)

        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received event :my_event
              with nil.

              Events received:
              {:my_other_event=>[{}]}
            MESSAGE
          end
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 2x' do
        track_event.call
        track_event.call

        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    context 'event name + hash' do
      let(:track_event) { -> { analytics.track_event :my_event, arg1: 42 } }
      let(:track_event_with_different_args) { -> { analytics.track_event :my_event, arg1: 43 } }
      let(:track_other_event) { -> { analytics.track_event :my_other_event } }
      let(:code_under_test) { -> { expect(analytics).to have_logged_event(:my_event, arg1: 42) } }

      it 'raises if no event has been logged' do
        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received event :my_event
              with {:arg1=>42}.

              Events received:
              {}
            MESSAGE
          end
      end

      it 'raises if another type of event has been logged' do
        track_other_event.call

        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received event :my_event
              with {:arg1=>42}.

              Events received:
              {:my_other_event=>[{}]}
            MESSAGE
          end
      end

      it 'raises if only a non-matching event of the same type has been logged' do
        track_event_with_different_args.call

        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received matching event my_event
              expected: {:arg1=>42}
                   got: {:arg1=>43}

              Diff:
              @@ -1 +1 @@
              -:arg1 => 42,
              +:arg1 => 43,              
            MESSAGE
          end
      end

      it 'does not raise if matching + non-matching event logged' do
        track_event.call
        track_event_with_different_args.call

        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 2x' do
        track_event.call
        track_event.call

        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    context 'event name + include() matcher' do
      let(:track_event) { -> { analytics.track_event :my_event, arg1: 42 } }
      let(:track_matching_event_with_more_args) do
        -> {
          analytics.track_event :my_event, arg1: 42, arg2: 43
        }
      end
      let(:track_event_with_different_args) { -> { analytics.track_event :my_event, arg1: 43 } }
      let(:track_other_event) { -> { analytics.track_event :my_other_event } }
      let(:code_under_test) do
        -> {
          expect(analytics).to have_logged_event(:my_event, include(arg1: 42))
        }
      end

      it 'raises if no event has been logged' do
        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received event :my_event
              with #<RSpec::Matchers::BuiltIn::Include:<id> @expecteds=[{:arg1=>42}]>.

              Events received:
              {}
            MESSAGE
          end
      end

      it 'raises if another type of event has been logged' do
        track_other_event.call

        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received event :my_event
              with #<RSpec::Matchers::BuiltIn::Include:<id> @expecteds=[{:arg1=>42}]>.

              Events received:
              {:my_other_event=>[{}]}
            MESSAGE
          end
      end

      it 'raises if only a non-matching event of the same type has been logged' do
        track_event_with_different_args.call

        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received matching event my_event
              expected: include {:arg1=>42}
                   got: {:arg1=>43}

              Diff:
              @@ -1 +1 @@
              -:arg1 => 42,
              +:arg1 => 43,
            MESSAGE
          end
      end

      it 'does not raise if matching + non-matching event logged' do
        track_event.call
        track_event_with_different_args.call

        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 2x' do
        track_event.call
        track_event.call

        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    context 'event name + hash_including() matcher' do
      let(:track_event) { -> { analytics.track_event :my_event, arg1: 42 } }
      let(:track_matching_event_with_more_args) do
        -> {
          analytics.track_event :my_event, arg1: 42, arg2: 43
        }
      end
      let(:track_event_with_different_args) { -> { analytics.track_event :my_event, arg1: 43 } }
      let(:track_other_event) { -> { analytics.track_event :my_other_event } }
      let(:code_under_test) do
        -> {
          expect(analytics).to have_logged_event(:my_event, hash_including(arg1: 42))
        }
      end

      it 'raises if no event has been logged' do
        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received event :my_event
              with #<RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher:<id> @expected={:arg1=>42}>.

              Events received:
              {}
            MESSAGE
          end
      end

      it 'raises if another type of event has been logged' do
        track_other_event.call

        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received event :my_event
              with #<RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher:<id> @expected={:arg1=>42}>.

              Events received:
              {:my_other_event=>[{}]}
            MESSAGE
          end
      end

      it 'raises if only a non-matching event of the same type has been logged' do
        track_event_with_different_args.call

        expect(&code_under_test).
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received event :my_event
              with #<RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher:<id> @expected={:arg1=>42}>.

              Events received:
              {:my_event=>[{:arg1=>43}]}
            MESSAGE
          end
      end

      it 'does not raise if matching + non-matching event logged' do
        track_event.call
        track_event_with_different_args.call

        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 2x' do
        track_event.call
        track_event.call

        expect(&code_under_test).
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end
  end

  describe FakeAnalytics::PiiAlerter do
    it 'throws an error when pii is passed in' do
      expect { analytics.track_event('Trackable Event') }.to_not raise_error

      expect { analytics.track_event('Trackable Event', first_name: 'Bobby') }.
        to raise_error(FakeAnalytics::PiiDetected)

      expect do
        analytics.track_event('Trackable Event', nested: [{ value: { first_name: 'Bobby' } }])
      end.to raise_error(FakeAnalytics::PiiDetected)

      expect { analytics.track_event('Trackable Event', decrypted_pii: '{"first_name":"Bobby"}') }.
        to raise_error(FakeAnalytics::PiiDetected)
    end

    it 'throws an error when it detects sample PII in the payload' do
      expect { analytics.track_event('Trackable Event', some_benign_key: 'FAKEY MCFAKERSON') }.
        to raise_error(FakeAnalytics::PiiDetected)
    end
  end

  describe FakeAnalytics::UndocumentedParamsChecker do
    it 'errors when undocumented parameters are sent' do
      expect do
        analytics.idv_phone_confirmation_otp_submitted(
          success: true,
          errors: true,
          code_expired: true,
          code_matches: true,
          second_factor_attempts_count: true,
          second_factor_locked_at: true,
          proofing_components: true,
          some_new_undocumented_keyword: true,
        )
      end.to raise_error(FakeAnalytics::UndocumentedParams, /some_new_undocumented_keyword/)
    end

    it 'does not error when undocumented params are allowed',
       allowed_extra_analytics: [:fun_level] do
      analytics.idv_phone_confirmation_otp_submitted(
        success: true,
        errors: true,
        code_expired: true,
        code_matches: true,
        second_factor_attempts_count: true,
        second_factor_locked_at: true,
        proofing_components: true,
        fun_level: 1000,
      )

      expect(analytics).to have_logged_event(
        'IdV: phone confirmation otp submitted',
        hash_including(:fun_level),
      )
    end

    it 'does not error when undocumented params are allowed via *', allowed_extra_analytics: [:*] do
      analytics.idv_phone_confirmation_otp_submitted(
        success: true,
        errors: true,
        code_expired: true,
        code_matches: true,
        second_factor_attempts_count: true,
        second_factor_locked_at: true,
        proofing_components: true,
        fun_level: 1000,
      )

      expect(analytics).to have_logged_event(
        'IdV: phone confirmation otp submitted',
        hash_including(:fun_level),
      )
    end

    it 'does not error when string tags are documented as options' do
      analytics.idv_doc_auth_submitted_image_upload_vendor(
        success: nil,
        errors: nil,
        exception: nil,
        state: nil,
        state_id_type: nil,
        async: nil,
        submit_attempts: nil,
        remaining_submit_attempts: nil,
        client_image_metrics: nil,
        flow_path: nil,
        liveness_checking_required: nil,
        'DocumentName' => 'some_name',
      )

      expect(analytics).to have_logged_event(
        'IdV: doc auth image upload vendor submitted',
        hash_including('DocumentName'),
      )
    end
  end

  def assert_error_messages_equal(err, expected)
    actual = normalize_error_message(err.message)
    expected = normalize_error_message(expected)
    expect(actual).to eql(expected)
  end

  def normalize_error_message(message)
    message.
      gsub(/\x1b\[[0-9;]*m/, ''). # Strip ANSI control characters used for color
      gsub(/:0x[0-9a-f]{16}/, ':<id>').
      strip
  end
end
