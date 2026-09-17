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

    context "On 'idv_state_id_validation' event" do
      # Payload shape taken from a real CloudWatch capture: AAMVA reached the Maryland MVA, which
      # verified most attributes but would not verify the ID number.
      def state_id_event(properties)
        {
          '@timestamp' => Time.zone.now,
          'name' => 'idv_state_id_validation',
          '@message' => {
            'properties' => {
              'event_properties' => {
                'vendor_name' => 'aamva:state_id',
                'aamva_checked' => true,
                'supported_jurisdiction' => true,
                'jurisdiction_in_maintenance_window' => false,
                'timed_out' => false,
                'mva_exception' => false,
                'state_id_jurisdiction' => 'MD',
              }.merge(properties),
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
        let(:event) do
          state_id_event(
            'success' => false,
            'verified_attributes' => %w[dob last_name first_name address],
            'errors' => {
              'state_id_number' => ['UNVERIFIED'],
              'state_id_issued' => ['UNVERIFIED'],
              'height' => ['MISSING'],
            },
          )
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
        let(:event) { state_id_event('success' => true, 'errors' => {}) }

        it 'adds no failure event' do
          expect(significant_events).to be_empty
        end
      end

      context 'when the check was skipped' do
        # AamvaPlugin#skipped_result / #unsupported_jurisdiction_result carry success: true, and
        # their vendor names are covered by RESOLUTION_SENTINELS if one arrives as a failure.
        let(:event) do
          state_id_event(
            'success' => true,
            'aamva_checked' => false,
            'vendor_name' => 'AamvaCheckSkipped',
            'errors' => {},
          )
        end

        it 'stays silent rather than reporting a failure the user never hit' do
          expect(significant_events).to be_empty
        end
      end

      context 'when the exception was on the configured bypass list' do
        # aamva_plugin.rb logs the pre-conversion result -- success: false -- and only then turns it
        # into a skip, so the user proceeded and there is nothing to report.
        let(:event) do
          state_id_event(
            'success' => false,
            'bypass_exception' => true,
            'exception' => 'ExceptionId: 0001',
            'errors' => {},
          )
        end

        it 'stays silent because the plugin converts this into a skip' do
          expect(significant_events).to be_empty
        end
      end

      context 'when AAMVA timed out' do
        let(:event) do
          state_id_event('success' => false, 'timed_out' => true, 'errors' => {})
        end

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

      def socure_event(properties)
        {
          '@timestamp' => Time.zone.now,
          'name' => 'idv_socure_verification_data_requested',
          '@message' => {
            'properties' => {
              'event_properties' => {
                'vendor' => 'Socure',
                'document_metadata' => { 'type' => 'Drivers License' },
              }.merge(properties),
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

      it 'says the images were accepted, not that the user was verified' do
        # The images being accepted is not the same as the submission passing: the same job then
        # runs the state ID check and can reject the submission seconds later. Claiming the user
        # "successfully verified their drivers license" here is wrong whenever that happens.
        matcher.handle_cloudwatch_event(socure_event('success' => true))

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

      it 'still reports vendor rejections with their reason codes' do
        matcher.handle_cloudwatch_event(
          socure_event('success' => false, 'reason_codes' => ['R836']),
        )

        expect(significant_events).to include(
          have_attributes(type: :socure_docv_failures),
        )
      end
    end

    context "On 'idv_doc_auth_socure_error_visited' event" do
      def error_visited_event(properties)
        {
          '@timestamp' => Time.zone.now,
          'name' => 'idv_doc_auth_socure_error_visited',
          '@message' => {
            'properties' => { 'event_properties' => properties },
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

      subject(:significant_events) { matcher.current_idv_attempt.significant_events }

      def socure_submission(success:)
        {
          '@timestamp' => Time.zone.now,
          'name' => 'idv_socure_verification_data_requested',
          '@message' => {
            'properties' => {
              'event_properties' => {
                'success' => success,
                'vendor' => 'Socure',
                'document_metadata' => { 'type' => 'Drivers License' },
                'reason_codes' => success ? [] : ['R836'],
              },
            },
          },
        }
      end

      it 'reports a submission ended by the state ID check' do
        # error_code 'state_id_verification' comes from Proofing::StateIdResult#doc_auth_errors:
        # the images were fine, AAMVA ended the submission. This is the case worth its own line --
        # the AAMVA result otherwise has nothing tying it to the submission outcome.
        matcher.handle_cloudwatch_event(socure_submission(success: true))
        matcher.handle_cloudwatch_event(
          error_visited_event('error_code' => 'state_id_verification'),
        )

        expect(significant_events).to include(
          have_attributes(
            type: :document_submission_rejected,
            description: 'Document submission rejected because the state ID check did not pass',
          ),
        )
      end

      it 'stays quiet when the vendor already reported the reason' do
        # The Socure DocV failure line already names the reason codes; a rejection line would
        # only repeat it.
        matcher.handle_cloudwatch_event(socure_submission(success: false))
        matcher.handle_cloudwatch_event(error_visited_event('error_code' => 'I834'))

        expect(significant_events).to include(
          have_attributes(type: :socure_docv_failures),
        )
        expect(significant_events).not_to include(
          have_attributes(type: :document_submission_rejected),
        )
      end

      it 'does not report a rejection with no submission behind it' do
        # This is a page-visit event: it fires on revisit and back-navigation too. Without a
        # submission awaiting an outcome there is nothing to report.
        matcher.handle_cloudwatch_event(
          error_visited_event('error_code' => 'state_id_verification'),
        )

        expect(significant_events).to be_empty
      end

      it 'reports one rejection per submission, not one per page view' do
        # Regression: the user submitted once at 11:47, was rejected, wandered to the ID type
        # chooser, and landed back on the error page at 11:48 -- producing two identical
        # rejection lines for a single submission.
        matcher.handle_cloudwatch_event(socure_submission(success: true))
        matcher.handle_cloudwatch_event(
          error_visited_event('error_code' => 'state_id_verification'),
        )
        matcher.handle_cloudwatch_event(
          error_visited_event('error_code' => 'state_id_verification'),
        )

        expect(
          significant_events.count { |e| e.type == :document_submission_rejected },
        ).to eq(1)
      end

      it 'reports the next submission after the flag is cleared' do
        2.times do
          matcher.handle_cloudwatch_event(socure_submission(success: true))
          matcher.handle_cloudwatch_event(
            error_visited_event('error_code' => 'state_id_verification'),
          )
        end

        expect(
          significant_events.count { |e| e.type == :document_submission_rejected },
        ).to eq(2)
      end
    end

    context "On 'IdV: in person proofing state_id submitted' event" do
      def ipp_state_id_event(success:)
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
      end

      subject(:significant_events) { matcher.current_idv_attempt.significant_events }

      it 'records that the state ID details were hand-entered' do
        # Without this, an AAMVA failure against typed data is indistinguishable from one against
        # data read off a document image -- which is the difference between a misread document and
        # the state having no matching record.
        matcher.handle_cloudwatch_event(ipp_state_id_event(success: true))

        expect(significant_events).to include(
          have_attributes(
            type: :ipp_state_id_entered,
            description: 'User entered their state ID details manually for in-person proofing',
          ),
        )
      end

      it 'ignores a failed form submission' do
        # Form validation failed, so nothing was sent to the state.
        matcher.handle_cloudwatch_event(ipp_state_id_event(success: false))

        expect(significant_events).to be_empty
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
        # Entering IPP makes the attempt workflow_complete?, which suppresses the abandonment
        # heuristic. The user was actively working through the IPP flow.
        expect(results.first[:attributes]).not_to include(
          hash_including(type: :idv_abandoned),
        )
      end
    end

    context "On 'Rate Limit Reached' event" do
      def rate_limit_event(properties)
        {
          '@timestamp' => Time.zone.now,
          'name' => 'Rate Limit Reached',
          '@message' => {
            'properties' => { 'event_properties' => properties },
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

      subject(:significant_events) { matcher.current_idv_attempt.significant_events }

      it 'names the step where the limit was hit' do
        # The idv_doc_auth limiter is shared between document capture and the IPP state ID step, so
        # the limiter name alone reads as though the user was still uploading documents.
        matcher.handle_cloudwatch_event(
          rate_limit_event('limiter_type' => 'idv_doc_auth', 'step_name' => 'ipp_state_id'),
        )

        expect(significant_events).to include(
          have_attributes(
            type: :rate_limited,
            description: 'Rate limited for Doc Auth while entering their state ID for ' \
                         'in-person proofing',
          ),
        )
      end

      it 'falls back to the limiter alone for an unrecognized step' do
        matcher.handle_cloudwatch_event(
          rate_limit_event('limiter_type' => 'idv_doc_auth', 'step_name' => 'something_new'),
        )

        expect(significant_events).to include(
          have_attributes(description: 'Rate limited for Doc Auth'),
        )
      end

      it 'falls back to the limiter alone when no step is given' do
        matcher.handle_cloudwatch_event(rate_limit_event('limiter_type' => 'idv_doc_auth'))

        expect(significant_events).to include(
          have_attributes(description: 'Rate limited for Doc Auth'),
        )
      end

      it 'ignores limiters it does not report on' do
        matcher.handle_cloudwatch_event(rate_limit_event('limiter_type' => 'idv_resolution'))

        expect(significant_events).to be_empty
      end
    end
  end
end
