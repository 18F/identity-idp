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

    def socure_submission(success:, reason_codes: [])
      {
        '@timestamp' => Time.zone.now,
        'name' => 'idv_socure_verification_data_requested',
        '@message' => {
          'properties' => {
            'event_properties' => {
              'success' => success,
              'vendor' => 'Socure',
              'document_metadata' => { 'type' => 'Drivers License' },
              'reason_codes' => reason_codes,
            },
          },
        },
      }
    end

    def error_visited_event(error_code:)
      {
        '@timestamp' => Time.zone.now,
        'name' => 'idv_doc_auth_socure_error_visited',
        '@message' => {
          'properties' => { 'event_properties' => { 'error_code' => error_code } },
        },
      }
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

    context "On 'idv_state_id_validation' event" do
      let(:success) { false }
      let(:vendor_name) { 'aamva:state_id' }
      let(:aamva_checked) { true }
      let(:bypass_exception) { nil }
      let(:timed_out) { false }
      let(:errors) { {} }

      let(:event) do
        {
          '@timestamp' => Time.zone.now,
          'name' => 'idv_state_id_validation',
          '@message' => {
            'properties' => {
              'event_properties' => {
                'success' => success,
                'vendor_name' => vendor_name,
                'aamva_checked' => aamva_checked,
                'bypass_exception' => bypass_exception,
                'supported_jurisdiction' => true,
                'timed_out' => timed_out,
                'mva_exception' => false,
                'state_id_jurisdiction' => 'MD',
                'errors' => errors,
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

      subject(:significant_events) { matcher.current_idv_attempt.significant_events }

      context 'when the state MVA would not verify the ID number' do
        let(:errors) do
          {
            'state_id_number' => ['UNVERIFIED'],
            'state_id_issued' => ['UNVERIFIED'],
            'height' => ['MISSING'],
          }
        end

        it 'reports the AAMVA failure and names the failed attributes' do
          expect(significant_events).to include(
            have_attributes(
              type: :aamva_error,
              description: a_string_including('state_id_number'),
            ),
          )
        end
      end

      context 'when AAMVA succeeded' do
        let(:success) { true }

        it 'adds no failure event' do
          expect(significant_events).to be_empty
        end
      end

      context 'when the check was skipped' do
        let(:success) { true }
        let(:aamva_checked) { false }
        let(:vendor_name) { 'AamvaCheckSkipped' }

        it 'stays silent rather than reporting a failure the user never hit' do
          expect(significant_events).to be_empty
        end
      end

      context 'when the exception was on the configured bypass list' do
        let(:bypass_exception) { true }

        it 'stays silent because the plugin converts this into a skip' do
          expect(significant_events).to be_empty
        end
      end

      context 'when AAMVA timed out' do
        let(:timed_out) { true }

        it 'reports the timeout' do
          expect(significant_events).to include(
            have_attributes(type: :aamva_timed_out),
          )
        end
      end
    end

    context "On 'idv_in_person_direct_start' event" do
      let(:event) do
        {
          '@timestamp' => Time.zone.now,
          'name' => 'idv_in_person_direct_start',
          '@message' => {
            'properties' => {
              'event_properties' => { 'flow_path' => 'standard' },
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

      it 'records IPP entry' do
        expect(matcher.current_idv_attempt.significant_events).to include(
          have_attributes(
            type: :start_ipp,
            description: 'User entered the in-person proofing flow',
          ),
        )
      end

      it 'marks the attempt as IPP so it is not reported as abandoned' do
        expect(matcher.current_idv_attempt.ipp?).to eq(true)
        expect(matcher.current_idv_attempt.workflow_complete?).to eq(true)
      end

      it 'does not repeat the line if final resolution later reports IPP pending' do
        matcher.handle_cloudwatch_event(
          {
            '@timestamp' => Time.zone.now,
            'name' => 'IdV: final resolution',
            '@message' => {
              'properties' => {
                'event_properties' => { 'in_person_verification_pending' => true },
              },
            },
          },
        )

        expect(
          matcher.current_idv_attempt.significant_events.count { |e| e.type == :start_ipp },
        ).to eq(1)
      end
    end

    describe 'reporting a document submission' do
      subject(:significant_events) { matcher.current_idv_attempt.significant_events }

      let(:success) { true }
      let(:reason_codes) { [] }

      let(:event) do
        socure_submission(success:, reason_codes:)
      end

      before do
        allow(matcher).to receive(:current_idv_attempt).and_return(
          EventSummarizer::IdvMatcher::IdvAttempt.new(
            started_at: Time.zone.now,
          ),
        )
        matcher.handle_cloudwatch_event(event)
      end

      context 'when the vendor accepted the images' do
        it 'says the images were accepted, not that the user was verified' do
          expect(significant_events).to include(
            have_attributes(
              type: :document_images_accepted,
              description: "Socure DocV accepted the user's drivers license images",
            ),
          )
          expect(significant_events).not_to include(
            have_attributes(description: a_string_including('successfully verified')),
          )
        end
      end

      context 'when the vendor rejected the images' do
        let(:success) { false }
        let(:reason_codes) { ['R836'] }

        it 'still reports the vendor reason codes' do
          expect(significant_events).to include(
            have_attributes(type: :socure_docv_failures),
          )
        end
      end
    end

    context "On 'idv_doc_auth_socure_error_visited' event" do
      before do
        allow(matcher).to receive(:current_idv_attempt).and_return(
          EventSummarizer::IdvMatcher::IdvAttempt.new(
            started_at: Time.zone.now,
          ),
        )
      end

      subject(:significant_events) { matcher.current_idv_attempt.significant_events }

      it 'reports a submission ended by the state ID check' do
        matcher.handle_cloudwatch_event(socure_submission(success: true))
        matcher.handle_cloudwatch_event(
          error_visited_event(error_code: 'state_id_verification'),
        )

        expect(significant_events).to include(
          have_attributes(
            type: :document_submission_rejected,
            description: 'Document submission rejected because the state ID check did not pass',
          ),
        )
      end

      it 'stays quiet when the vendor already reported the reason' do
        matcher.handle_cloudwatch_event(
          socure_submission(success: false, reason_codes: ['R836']),
        )
        matcher.handle_cloudwatch_event(error_visited_event(error_code: 'I834'))

        expect(significant_events).to include(
          have_attributes(type: :socure_docv_failures),
        )
        expect(significant_events).not_to include(
          have_attributes(type: :document_submission_rejected),
        )
      end

      it 'does not report a rejection with no submission behind it' do
        matcher.handle_cloudwatch_event(
          error_visited_event(error_code: 'state_id_verification'),
        )

        expect(significant_events).to be_empty
      end

      it 'reports one rejection per submission, not one per page view' do
        matcher.handle_cloudwatch_event(socure_submission(success: true))
        matcher.handle_cloudwatch_event(
          error_visited_event(error_code: 'state_id_verification'),
        )
        matcher.handle_cloudwatch_event(
          error_visited_event(error_code: 'state_id_verification'),
        )

        expect(
          significant_events.count { |e| e.type == :document_submission_rejected },
        ).to eq(1)
      end

      it 'reports the next submission after the flag is cleared' do
        2.times do
          matcher.handle_cloudwatch_event(socure_submission(success: true))
          matcher.handle_cloudwatch_event(
            error_visited_event(error_code: 'state_id_verification'),
          )
        end

        expect(
          significant_events.count { |e| e.type == :document_submission_rejected },
        ).to eq(2)
      end
    end

    context "On 'IdV: in person proofing state_id submitted' event" do
      let(:success) { true }

      let(:event) do
        {
          '@timestamp' => Time.zone.now,
          'name' => 'IdV: in person proofing state_id submitted',
          '@message' => {
            'properties' => {
              'event_properties' => {
                'success' => success,
                'step' => 'state_id',
                'flow_path' => 'hybrid',
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

      subject(:significant_events) { matcher.current_idv_attempt.significant_events }

      it 'records that the state ID details were hand-entered' do
        expect(significant_events).to include(
          have_attributes(
            type: :ipp_state_id_entered,
            description: 'User entered their state ID details manually for in-person proofing',
          ),
        )
      end

      context 'when the form submission failed' do
        let(:success) { false }

        it 'adds no event' do
          expect(significant_events).to be_empty
        end
      end
    end

    describe 'an attempt that entered IPP and did not finish' do
      let(:welcome_event) do
        {
          '@timestamp' => 3.hours.ago,
          'name' => 'IdV: doc auth welcome submitted',
        }
      end

      subject(:results) { matcher.finish }

      before do
        matcher.handle_cloudwatch_event(welcome_event)
        matcher.handle_cloudwatch_event(
          {
            '@timestamp' => 2.hours.ago,
            'name' => 'idv_in_person_direct_start',
            '@message' => { 'properties' => { 'event_properties' => {} } },
          },
        )
      end

      it 'reports entering IPP and nothing further' do
        expect(results.first[:attributes]).to include(
          hash_including(type: :start_ipp),
        )
        expect(results.first[:attributes].last[:type]).to eq(:start_ipp)
      end

      it 'does not claim the user abandoned verification' do
        expect(results.first[:attributes]).not_to include(
          hash_including(type: :idv_abandoned),
        )
      end
    end

    context "On 'Rate Limit Reached' event" do
      let(:limiter_type) { 'idv_doc_auth' }
      let(:step_name) { nil }

      let(:event) do
        {
          '@timestamp' => Time.zone.now,
          'name' => 'Rate Limit Reached',
          '@message' => {
            'properties' => {
              'event_properties' => {
                'limiter_type' => limiter_type,
                'step_name' => step_name,
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

      subject(:significant_events) { matcher.current_idv_attempt.significant_events }

      context 'when the step is one we can name' do
        let(:step_name) { 'ipp_state_id' }

        it 'names the step where the limit was hit' do
          expect(significant_events).to include(
            have_attributes(
              type: :rate_limited,
              description: 'Rate limited for Doc Auth while entering their state ID for ' \
                           'in-person proofing',
            ),
          )
        end
      end

      context 'when the step is unrecognized' do
        let(:step_name) { 'something_new' }

        it 'falls back to the limiter alone' do
          expect(significant_events).to include(
            have_attributes(description: 'Rate limited for Doc Auth'),
          )
        end
      end

      context 'when no step is given' do
        it 'falls back to the limiter alone' do
          expect(significant_events).to include(
            have_attributes(description: 'Rate limited for Doc Auth'),
          )
        end
      end

      context 'when the limiter is not one we report on' do
        let(:limiter_type) { 'idv_resolution' }

        it 'adds no event' do
          expect(significant_events).to be_empty
        end
      end
    end
  end
end
