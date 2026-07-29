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

    context "On 'IdV: doc auth verify proofing results' event (failed resolution)" do
      before do
        allow(matcher).to receive(:current_idv_attempt).and_return(
          EventSummarizer::IdvMatcher::IdvAttempt.new(
            started_at: Time.zone.now,
          ),
        )
        matcher.handle_cloudwatch_event(event)
      end

      subject(:significant_events) { matcher.current_idv_attempt.significant_events }

      context 'when the resolution vendor is the post-cutover DDP Instant Verify key' do
        let(:event) do
          {
            'name' => 'IdV: doc auth verify proofing results',
            '@message' => {
              'properties' => {
                'event_properties' => {
                  'success' => false,
                  'proofing_results' => {
                    'context' => {
                      'stages' => {
                        'resolution' => {
                          'success' => false,
                          'vendor_name' => 'lexisnexis:instant_verify_ddp',
                        },
                      },
                    },
                  },
                },
              },
            },
          }
        end

        it 'uses the Instant Verify evaluator instead of reporting Unknown vendor' do
          expect(significant_events).to include(
            have_attributes(
              type: :instant_verify_error,
              description: a_string_starting_with('Instant Verify request failed'),
            ),
          )
          expect(significant_events).not_to include(
            have_attributes(description: a_string_including('Unknown vendor')),
          )
        end
      end

      context 'when the phone vendor is the post-cutover DDP Phone Finder key' do
        let(:event) do
          {
            'name' => 'IdV: doc auth verify proofing results',
            '@message' => {
              'properties' => {
                'event_properties' => {
                  'success' => false,
                  'proofing_results' => {
                    'context' => {
                      'stages' => {
                        'resolution' => {
                          'success' => false,
                          'vendor_name' => 'lexisnexis:phone_finder_ddp',
                        },
                      },
                    },
                  },
                },
              },
            },
          }
        end

        it 'uses the Phone Finder evaluator instead of reporting Unknown vendor' do
          expect(significant_events).to include(
            have_attributes(
              type: :phone_finder_error,
              description: a_string_starting_with('Phone Finder check failed'),
            ),
          )
          expect(significant_events).not_to include(
            have_attributes(description: a_string_including('Unknown vendor')),
          )
        end
      end

      context 'when a stage carries a resolution sentinel (not a real vendor call)' do
        let(:event) do
          {
            'name' => 'IdV: doc auth verify proofing results',
            '@message' => {
              'properties' => {
                'event_properties' => {
                  'success' => false,
                  'proofing_results' => {
                    'context' => {
                      'stages' => {
                        'resolution' => {
                          'success' => false,
                          'vendor_name' => 'ResolutionCannotPass',
                        },
                      },
                    },
                  },
                },
              },
            },
          }
        end

        it 'explains the skip rather than reporting a failed vendor request' do
          expect(significant_events).to include(
            have_attributes(
              type: :resolution_cannot_pass_skipped,
              description: 'Phone check was skipped because identity resolution could not pass',
            ),
          )
          expect(significant_events).not_to include(
            have_attributes(description: a_string_including('failed.')),
          )
        end
      end

      context 'when the vendor key is genuinely unrecognized' do
        let(:event) do
          {
            'name' => 'IdV: doc auth verify proofing results',
            '@message' => {
              'properties' => {
                'event_properties' => {
                  'success' => false,
                  'proofing_results' => {
                    'context' => {
                      'stages' => {
                        'resolution' => {
                          'success' => false,
                          'vendor_name' => 'brand:new_vendor',
                        },
                      },
                    },
                  },
                },
              },
            },
          }
        end

        it 'names the raw vendor key rather than the opaque Unknown vendor' do
          expect(significant_events).to include(
            have_attributes(
              type: :unknown_request_failed,
              description: 'Request to an unrecognized vendor (brand:new_vendor) failed.',
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
