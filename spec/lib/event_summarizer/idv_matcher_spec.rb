require 'active_support'
require 'active_support/time'

require 'event_summarizer/idv_matcher'

RSpec.describe EventSummarizer::IdvMatcher do
  describe '#handle_cloudwatch_event' do
    let(:event) do
      {
        '@timestamp': '2024-01-02T03:04:05Z',
      }
    end

    subject(:matcher) do
      described_class.new
    end

    around do |example|
      Time.use_zone('UTC') do
        example.run
      end
    end

    context 'On unknown event' do
      let(:event) { super().merge('name' => 'Some random event') }
      it 'does not throw' do
        matcher.handle_cloudwatch_event(event)
      end
    end

    context "On 'IdV: doc auth welcome submitted' event" do
      let(:event) { super().merge('name' => 'IdV: doc auth welcome submitted') }

      it 'starts a new IdV attempt' do
        matcher.handle_cloudwatch_event(event)
        expect(matcher.current_idv_attempt).not_to eql(nil)
      end

      context 'with an IdV attempt already started' do
        before do
          allow(matcher).to receive(:current_idv_attempt).and_return(
            EventSummarizer::IdvMatcher::IdvAttempt.new(
              started_at: Time.zone.now,
            ),
          )
        end

        it 'finishes it' do
          expect(matcher.idv_attempts.length).to eql(0)
          matcher.handle_cloudwatch_event(event)
          expect(matcher.idv_attempts.length).to eql(1)
        end
      end
    end

    context "On 'IdV: phone confirmation vendor' event" do
      context 'When the vendor is Phone Finder' do
        let(:event) do
          {
            '@timestamp' => Time.zone.now,
            'name' => 'IdV: phone confirmation vendor',
            '@message' => {
              'properties' => {
                'event_properties' => {
                  'success' => true,
                  'vendor' => {
                    'vendor_name' => 'lexisnexis:phone_finder',
                  },
                },
              },
            },
          }
        end

        before do
          allow(matcher).to receive(:current_idv_attempt).and_return(
            EventSummarizer::IdvMatcher::IdvAttempt.new(
              started_at: Time.zone.now,
            ),
          )
        end

        it 'adds a passed_phone_finder significant event when successful' do
          matcher.handle_cloudwatch_event(event)

          expect(matcher.current_idv_attempt.significant_events).to include(
            have_attributes(
              type: :passed_phone_confirmation,
              description: 'Phone confirmation check succeeded via Phone Finder',
            ),
          )
        end
      end

      context 'When the vendor is Phone Risk' do
        let(:event) do
          {
            '@timestamp' => Time.zone.now,
            'name' => 'IdV: phone confirmation vendor',
            '@message' => {
              'properties' => {
                'event_properties' => {
                  'success' => true,
                  'vendor' => {
                    'vendor_name' => 'socure_phonerisk',
                  },
                },
              },
            },
          }
        end

        before do
          allow(matcher).to receive(:current_idv_attempt).and_return(
            EventSummarizer::IdvMatcher::IdvAttempt.new(
              started_at: Time.zone.now,
            ),
          )
        end

        it 'adds a passed_phone_confirmation significant event when successful' do
          matcher.handle_cloudwatch_event(event)

          expect(matcher.current_idv_attempt.significant_events).to include(
            have_attributes(
              type: :passed_phone_confirmation,
              description: 'Phone confirmation check succeeded via Socure Phone Risk',
            ),
          )
        end
      end

      context 'When the vendor is Unknown' do
        let(:event) do
          {
            '@timestamp' => Time.zone.now,
            'name' => 'IdV: phone confirmation vendor',
            '@message' => {
              'properties' => {
                'event_properties' => {
                  'success' => true,
                  'vendor' => {
                    'vendor_name' => 'an unknown vendor',
                  },
                },
              },
            },
          }
        end

        before do
          allow(matcher).to receive(:current_idv_attempt).and_return(
            EventSummarizer::IdvMatcher::IdvAttempt.new(
              started_at: Time.zone.now,
            ),
          )
        end

        it 'adds a passed_phone_confirmation significant event when successful' do
          matcher.handle_cloudwatch_event(event)

          expect(matcher.current_idv_attempt.significant_events).to include(
            have_attributes(
              type: :passed_phone_confirmation,
              description: 'Phone confirmation check succeeded via Unknown vendor',
            ),
          )
        end
      end
    end

    context "On 'IdV: use different phone number' (Phone Verification Step) event" do
      let(:event) do
        {
          '@timestamp' => Time.zone.now,
          'name' => 'IdV: use different phone number',
          '@message' => {
            'properties' => {
              'event_properties' => {
                'step' => 'phone_otp_verification',
              },
            },
          },
        }
      end

      before do
        allow(matcher).to receive(:current_idv_attempt).and_return(
          EventSummarizer::IdvMatcher::IdvAttempt.new(
            started_at: Time.zone.now,
          ),
        )
        matcher.handle_cloudwatch_event(event)
      end

      it 'adds a different_phone_number significant event when present' do
        expect(matcher.current_idv_attempt.significant_events).to include(
          have_attributes(
            type: :different_phone_number,
            description: 'User attempted to use a different phone number',
          ),
        )
      end
    end
  end
end
