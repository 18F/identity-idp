require 'rails_helper'

RSpec.describe Proofing::LexisNexis::Ddp::Proofers::PhoneFinderProofer do
  let(:proofing_applicant) do
    {
      first_name: 'Testy',
      last_name: 'McTesterson',
      dob: '01/01/1980',
      phone: '5551231234',
      uuid_prefix: 'ABCD',
      uuid: 'ABCD-1234-5678-9012',
    }
  end

  let(:proofing_verification_request) do
    Proofing::LexisNexis::Ddp::Requests::PhoneFinderRequest.new(
      applicant: proofing_applicant,
      config: LexisNexisFixtures.example_ddp_proofing_config,
    )
  end

  let(:issuer) { 'fake-issuer' }
  let(:friendly_name) { 'fake-name' }
  let(:app_id) { 'fake-app-id' }

  describe '#send' do
    context 'when the request times out' do
      it 'raises a timeout error' do
        stub_request(
          :post,
          proofing_verification_request.url,
        ).to_timeout

        expect { proofing_verification_request.send_request }.to raise_error(
          Proofing::TimeoutError,
          'LexisNexis timed out waiting for verification response',
        )
      end
    end

    context 'when the request is made' do
      it 'it looks like the right request' do
        request =
          stub_request(
            :post,
            proofing_verification_request.url,
          ).with(
            body: proofing_verification_request.body,
            headers: proofing_verification_request.headers,
          ).to_return(
            body: LexisNexisFixtures.ddp_instant_verify_success_response_json,
            status: 200,
          )

        proofing_verification_request.send_request

        expect(request).to have_been_requested.once
      end
    end
  end

  subject(:proofer) do
    described_class.new(LexisNexisFixtures.example_ddp_proofing_config.to_h)
  end

  describe '#proof' do
    before do
      allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id)
        .and_return('test_org_id')
      ServiceProvider.create(
        issuer: issuer,
        friendly_name: friendly_name,
        app_id: app_id,
      )
      stub_request(
        :post,
        proofing_verification_request.url,
      ).to_return(
        body: response_body,
        status: 200,
      )
    end

    context 'when user is going through Idv' do
      context 'when the response is a success' do
        let(:response_body) { LexisNexisFixtures.ddp_phone_finder_success_response_json }
        let(:expected_phone_metadata) do
          {
            phone_type: 'POSSIBLE WIRELESS',
            account_telephone_type: 'UNKNOWN',
            risk_indicator_status: 'PASS',
            risk_count_high: '0',
            risk_count_med: '1',
            risk_count_low: '4',
          }
        end

        it 'is a successful result' do
          result = proofer.proof(proofing_applicant)

          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
          expect(result.transaction_id).to eq('super-cool-test-session-id')
          expect(result.vendor_name).to eq('lexisnexis:phone_finder_ddp')
          expect(result.dual_vendor_check_eligible).to be(false)
        end

        it 'surfaces phone metadata in result' do
          result = proofer.proof(proofing_applicant)

          expect(result.result).to eq(expected_phone_metadata)
        end

        context 'when the phone metadata fields are absent' do
          let(:response_body) do
            {
              'integration_hub_results' => {
                'test_org_id:test-policy' => {
                  'Phone Finder' => {
                    'tps_vendor_raw_response' => {
                      'Products' => [],
                      'Status' => {
                        'ConversationId' => 'super-cool-test-session-id',
                        'TransactionStatus' => 'passed',
                      },
                    },
                  },
                },
              },
            }.to_json
          end

          it 'returns a nil result' do
            result = proofer.proof(proofing_applicant)

            expect(result.result).to be_nil
          end
        end
      end

      context 'when the response raises an exception' do
        let(:response_body) { '' }

        it 'returns an exception result' do
          error = RuntimeError.new('hi')

          expect(NewRelic::Agent).to receive(:notice_error).with(error)

          stub_request(
            :post,
            proofing_verification_request.url,
          ).to_raise(error)

          result = proofer.proof(proofing_applicant)

          expect(result.success?).to eq(false)
          expect(result.errors).to be_empty
          expect(result.exception).to eq(error)
          expect(result.dual_vendor_check_eligible).to be(false)
        end
      end

      context 'when the response is a failure' do
        let(:response_body) { LexisNexisFixtures.ddp_phone_finder_fail_response_json }

        context 'when the failure is "could not be verified to name" without additional errors' do
          it 'is a failure result' do
            result = proofer.proof(proofing_applicant)
            result_json_hash = result.errors[:'PhoneFinder Checks'].first

            expect(result.success?).to eq(false)
            expect(result_json_hash['ProductStatus']).to eq('fail')
            expect(result.transaction_id).to eq('super-cool-test-session-id')
            expect(result.vendor_name).to eq('lexisnexis:phone_finder_ddp')
            expect(result.dual_vendor_check_eligible).to be(true)
          end
        end

        context 'when the failure is "could not be verified to name" with additional errors' do
          let(:response_body) do
            {
              'integration_hub_results' => {
                'test_org_id:test-policy' => {
                  'Phone Finder' => {
                    'tps_vendor_raw_response' => {
                      'Products' => [
                        {
                          'ExecutedStepName' => 'PhoneFinder',
                          'ProductStatus' => 'fail',
                          'ProductType' => 'PhoneFinder',
                          'ProductReason' => {
                            'Code' => 'phone_finder_fail',
                            'Description' => 'Phone Finder Fail',
                          },
                          'Items' => [
                            {
                              'ItemName' => 'VOIPPhone',
                              'ItemReason' => {
                                'Code' => 'VOIPPHONE.HIGH',
                                'Description' => 'VOIP phone detected',
                              },
                              'ItemStatus' => 'fail',
                            },
                          ],
                        }, {
                          'ExecutedStepName' => 'PhoneFinder Checks',
                          'ProductType' => 'PhoneFinder_Decision',
                          'ProductStatus' => 'fail',
                          'ProductReason' => {
                            'Code' => 'phone_finder_fail',
                            'Description' =>
                              'Failed - Input phone number could not be verified to name',
                          },
                        }
                      ],
                      'Status' => {
                        'ConversationId' => 'super-cool-test-session-id',
                        'TransactionReasonCode' => {
                          'Code' => 'phone_finder_fail',
                          'Description' =>
                            'Failed - Input phone number could not be verified to name',
                        },
                        'TransactionStatus' => 'failed',
                      },
                    },
                  },
                },
              },
            }.to_json
          end

          it 'is a failure result' do
            result = proofer.proof(proofing_applicant)
            result_json_hash = result.errors[:'PhoneFinder Checks'].first

            expect(result.success?).to eq(false)
            expect(result_json_hash['ProductStatus']).to eq('fail')
            expect(result.transaction_id).to eq('super-cool-test-session-id')
            expect(result.vendor_name).to eq('lexisnexis:phone_finder_ddp')
            expect(result.dual_vendor_check_eligible).to be(false)
          end
        end

        context 'when the response fails with "Risk Indicators match determined"' do
          let(:response_body) do
            {
              'integration_hub_results' => {
                'test_org_id:test-policy' => {
                  'Phone Finder' => {
                    'tps_vendor_raw_response' => {
                      'Products' => [
                        {
                          'ExecutedStepName' => 'PhoneFinder',
                          'ProductStatus' => 'fail',
                          'ProductType' => 'PhoneFinder',
                          'ProductReason' => {
                            'Code' => 'phone_finder_fail',
                            'Description' => 'Phone Finder Fail',
                          },
                          'Items' => [
                            {
                              'ItemName' => 'VOIPPhone',
                              'ItemReason' => {
                                'Code' => 'VOIPPHONE.HIGH',
                                'Description' => 'VOIP phone detected',
                              },
                              'ItemStatus' => 'fail',
                            },
                          ],
                        }, {
                          'ExecutedStepName' => 'PhoneFinder Checks',
                          'ProductType' => 'PhoneFinder_Decision',
                          'ProductStatus' => 'fail',
                          'ProductReason' => {
                            'Code' => 'phone_finder_fail',
                            'Description' => 'Fail - Risk Indicators match determined',
                          },
                        }
                      ],
                      'Status' => {
                        'ConversationId' => 'super-cool-test-session-id',
                        'TransactionReasonCode' => {
                          'Code' => 'phone_finder_fail',
                          'Description' => 'Fail - Risk Indicators match determined',
                        },
                        'TransactionStatus' => 'failed',
                      },
                    },
                  },
                },
              },
            }.to_json
          end

          it 'is a failure result' do
            result = proofer.proof(proofing_applicant)
            result_json_hash = result.errors[:'PhoneFinder Checks'].first

            expect(result.success?).to eq(false)
            expect(result_json_hash['ProductStatus']).to eq('fail')
            expect(result.transaction_id).to eq('super-cool-test-session-id')
            expect(result.vendor_name).to eq('lexisnexis:phone_finder_ddp')
            expect(result.dual_vendor_check_eligible).to be(false)
          end
        end
      end

      context 'when the response is missing tps_vendor_raw_response' do
        let(:service_block) do
          {}
        end
        let(:response_body) do
          {
            'integration_hub_results' => {
              'test_org_id:test-policy' => {
                'Phone Finder' => service_block,
              },
            },
          }.to_json
        end

        context 'when the service block indicates a vendor timeout' do
          let(:service_block) do
            { tps_was_timeout: 'yes' }
          end

          it 'returns a result whose exception is a Proofing::TimeoutError' do
            expect(NewRelic::Agent).to receive(:notice_error)
              .with(an_instance_of(Proofing::TimeoutError))

            result = proofer.proof(proofing_applicant)

            expect(result.success?).to eq(false)
            expect(result.timed_out?).to eq(true)
            expect(result.exception).to be_a(Proofing::TimeoutError)
            expect(result.exception.message)
              .to eq('LexisNexis PhoneFinder DDP timed out')
            expect(result.dual_vendor_check_eligible).to be(false)
          end
        end

        context 'when the service block does not indicate a timeout' do
          let(:service_block) do
            { tps_was_timeout: 'no', tps_error: 'phone_finder_error' }
          end

          it 'returns a result with a non-timeout RuntimeError exception' do
            expect(NewRelic::Agent).to receive(:notice_error)
              .with(an_instance_of(RuntimeError))

            result = proofer.proof(proofing_applicant)

            expect(result.success?).to eq(false)
            expect(result.timed_out?).to eq(false)
            expect(result.exception).to be_a(RuntimeError)
            expect(result.exception.message)
              .to eq('LexisNexis PhoneFinder DDP returned no tps_vendor_raw_response')
            expect(result.dual_vendor_check_eligible).to be(false)
          end
        end

        context 'when the service block is entirely absent from integration_hub_results' do
          let(:response_body) do
            { integration_hub_results: {} }.to_json
          end

          it 'returns a result with a non-timeout RuntimeError exception' do
            expect(NewRelic::Agent).to receive(:notice_error)
              .with(an_instance_of(RuntimeError))

            result = proofer.proof(proofing_applicant)

            expect(result.success?).to eq(false)
            expect(result.timed_out?).to eq(false)
            expect(result.exception).to be_a(RuntimeError)
            expect(result.exception.message)
              .to eq('LexisNexis PhoneFinder DDP returned no tps_vendor_raw_response')
            expect(result.dual_vendor_check_eligible).to be(false)
          end
        end
      end
    end
  end
end
