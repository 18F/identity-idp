require 'rails_helper'

RSpec.describe FakeAnalytics do
  subject { described_class.new }

  describe '#have_logged_event' do
    context 'no arguments' do
      let(:track_event) { -> { subject.track_event :my_event } }
      let(:expectation) { -> { have_logged_event } }

      it 'raises if event was not logged' do
        expect { expect(subject).to(expectation.call) }.
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
        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 2x' do
        track_event.call
        track_event.call

        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    context 'event name only' do
      let(:track_event) { -> { subject.track_event :my_event } }
      let(:expectation) { -> { have_logged_event :my_event } }

      it 'raises if no event has been logged' do
        expect { expect(subject).to(expectation.call) }.
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
        subject.track_event(:my_other_event)

        expect { expect(subject).to(expectation.call) }.
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
        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 2x' do
        track_event.call
        track_event.call

        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    context 'event name + hash' do
      let(:track_event) { -> { subject.track_event :my_event, arg1: 42 } }
      let(:track_event_with_different_args) { -> { subject.track_event :my_event, arg1: 43 } }
      let(:track_other_event) { -> { subject.track_event :my_other_event } }
      let(:expectation) { -> { have_logged_event :my_event, arg1: 42 } }

      it 'raises if no event has been logged' do
        expect { expect(subject).to(expectation.call) }.
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

        expect { expect(subject).to(expectation.call) }.
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

        expect { expect(subject).to(expectation.call) }.
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

        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 2x' do
        track_event.call
        track_event.call

        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    context 'event name + include() matcher' do
      let(:track_event) { -> { subject.track_event :my_event, arg1: 42 } }
      let(:track_matching_event_with_more_args) do
        -> {
          subject.track_event :my_event, arg1: 42, arg2: 43
        }
      end
      let(:track_event_with_different_args) { -> { subject.track_event :my_event, arg1: 43 } }
      let(:track_other_event) { -> { subject.track_event :my_other_event } }
      let(:expectation) { -> { have_logged_event :my_event, include(arg1: 42) } }

      it 'raises if no event has been logged' do
        expect { expect(subject).to(expectation.call) }.
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

        expect { expect(subject).to(expectation.call) }.
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

        expect { expect(subject).to(expectation.call) }.
          to raise_error(RSpec::Expectations::ExpectationNotMetError) do |err|
            assert_error_messages_equal(err, <<~MESSAGE)
              Expected that FakeAnalytics would have received matching event my_eventexpected: include {:arg1=>42}
                   got: {:arg1=>43}

              Diff:
              @@ -1 +1 @@
              -:arg1 => 42,
              +:arg1 => 43,

              Attributes ignored by the include matcher:
            MESSAGE
          end
      end

      it 'does not raise if matching + non-matching event logged' do
        track_event.call
        track_event_with_different_args.call

        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 2x' do
        track_event.call
        track_event.call

        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
    end

    context 'event name + hash_including() matcher' do
      let(:track_event) { -> { subject.track_event :my_event, arg1: 42 } }
      let(:track_matching_event_with_more_args) do
        -> {
          subject.track_event :my_event, arg1: 42, arg2: 43
        }
      end
      let(:track_event_with_different_args) { -> { subject.track_event :my_event, arg1: 43 } }
      let(:track_other_event) { -> { subject.track_event :my_other_event } }
      let(:expectation) { -> { have_logged_event :my_event, hash_including(arg1: 42) } }

      it 'raises if no event has been logged' do
        expect { expect(subject).to(expectation.call) }.
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

        expect { expect(subject).to(expectation.call) }.
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

        expect { expect(subject).to(expectation.call) }.
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

        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 1x' do
        track_event.call
        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end

      it 'does not raise if event was logged 2x' do
        track_event.call
        track_event.call

        expect { expect(subject).to(expectation.call) }.
          not_to raise_error(RSpec::Expectations::ExpectationNotMetError)
      end
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
