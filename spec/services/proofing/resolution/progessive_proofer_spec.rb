require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS }
  let(:should_proof_state_id) { true }
  let(:double_address_verification) { false }
  let(:request_ip) { Faker::Internet.ip_v4_address }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:timer) { JobHelpers::Timer.new }
  let(:user) { create(:user, :signed_up) }
  let(:instant_verify_proofer) { instance_double(Proofing::LexisNexis::InstantVerify::Proofer) }
  let(:instance) { described_class.new }

  describe '#proof' do
    before do
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
      allow(Proofing::LexisNexis::InstantVerify::VerificationRequest).to receive(:new)
    end
    subject(:proof) do
      instance.proof(
        applicant_pii: applicant_pii,
        double_address_verification: double_address_verification,
        request_ip: request_ip,
        should_proof_state_id: should_proof_state_id,
        threatmetrix_session_id: threatmetrix_session_id,
        timer: timer,
        user_email: user.confirmed_email_addresses.first.email,
      )
    end

    it 'returns a ResultAdjudicator' do
      expect(proof).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
    end

    context 'when double address verification is enabled' do
      before do
        allow(instance).to receive(:resolution_proofer).and_return(instant_verify_proofer)
      end

      let(:resolution_result) do
        instance_double(Proofing::Resolution::Result)
      end
      let(:double_address_verification) { true }
      let(:residential_address) do
        {
          address1: applicant_pii[:address1],
          address2: applicant_pii[:address2],
          city: applicant_pii[:city],
          state: applicant_pii[:state],
          state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
          zipcode: applicant_pii[:zipcode],
        }
      end
      let(:state_id_address) do
        {
          address1: applicant_pii[:identity_doc_address1],
          address2: applicant_pii[:identity_doc_address2],
          city: applicant_pii[:identity_doc_city],
          state: applicant_pii[:identity_doc_address_state],
          state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
          zipcode: applicant_pii[:identity_doc_zipcode],
        }
      end
      it 'makes a request to the Instant Verify proofer' do
        expect(instant_verify_proofer).to receive(:proof).with(hash_including(residential_address))
        expect(instant_verify_proofer).to receive(:proof).with(hash_including(state_id_address))
        allow(resolution_result).to receive(:success?).and_return(true)
        allow(instance).to receive(:proof_state_id_if_needed)

        subject
      end

      context 'ThreatMetrix is enabled' do
        let(:threatmetrix_proofer) { instance_double(Proofing::LexisNexis::Ddp::Proofer) }

        before do
          allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?).
            and_return(true)
          allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_mock_enabled).
            and_return(false)
          allow(instance).to receive(:lexisnexis_ddp_proofer).and_return(threatmetrix_proofer)

          allow(instance).to receive(:proof_resolution).and_return(resolution_result)
          allow(resolution_result).to receive(:success?).and_return(true)
          allow(instant_verify_proofer).to receive(:proof)
        end

        it 'makes a request to the ThreatMetrix proofer' do
          expect(threatmetrix_proofer).to receive(:proof)

          subject
        end

        context 'it lacks a session id' do
          let(:threatmetrix_session_id) { nil }
          it 'returns a disabled result' do
            result = subject

            device_profiling_result = result.device_profiling_result

            expect(device_profiling_result.success).to be(true)
            expect(device_profiling_result.client).to eq('tmx_disabled')
            expect(device_profiling_result.review_status).to eq('pass')
          end
        end
      end

      context 'ThreatMetrix is disabled' do
        before do
          allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?).
            and_return(false)

          allow(instance).to receive(:proof_resolution).and_return(resolution_result)
          allow(resolution_result).to receive(:success?).and_return(true)
          allow(instant_verify_proofer).to receive(:proof)
        end
        it 'returns a disabled result' do
          result = subject

          device_profiling_result = result.device_profiling_result

          expect(device_profiling_result.success).to be(true)
          expect(device_profiling_result.client).to eq('tmx_disabled')
          expect(device_profiling_result.review_status).to eq('pass')
        end
      end

      context 'Instant Verify passes' do
        let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer) }
        before do
          allow(instance).to receive(:state_id_proofer).and_return(aamva_proofer)
        end

        context 'user is in an AAMVA jurisdiction' do
          let(:resolution_result_that_passed_instant_verify) do
            instance_double(Proofing::Resolution::Result)
          end

          before do
            allow(instance).to receive(:proof_resolution).
              and_return(resolution_result_that_passed_instant_verify)
            allow(instant_verify_proofer).to receive(:proof).with(hash_including(state_id_address)).
              and_return(resolution_result_that_passed_instant_verify)
            allow(instance).to receive(:user_can_pass_after_state_id_check?).
              with(resolution_result_that_passed_instant_verify).
              and_return(true)
            allow(resolution_result_that_passed_instant_verify).to receive(:success?).
              and_return(true)
          end

          it 'makes a request to the AAMVA proofer' do
            expect(aamva_proofer).to receive(:proof)

            subject
          end

          context 'AAMVA proofing fails' do
            let(:aamva_client) { instance_double(Proofing::Aamva::VerificationClient) }
            let(:failed_aamva_proof) do
              instance_double(Proofing::StateIdResult)
            end
            before do
              allow(Proofing::Aamva::VerificationClient).to receive(:new).and_return(aamva_client)
              allow(failed_aamva_proof).to receive(:success?).and_return(false)
            end
            it 'returns a result adjudicator that indicates the aamva proofing failed' do
              allow(aamva_proofer).to receive(:proof).and_return(failed_aamva_proof)

              result = subject

              expect(result.state_id_result.success?).to eq(false)
            end
          end
        end
      end

      context 'Instant Verify fails' do
        let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer) }
        let(:result_that_failed_instant_verify) do
          instance_double(Proofing::Resolution::Result)
        end

        before do
          allow(instance).to receive(:state_id_proofer).and_return(aamva_proofer)
          allow(instance).to receive(:proof_resolution).
            and_return(result_that_failed_instant_verify)
          allow(instant_verify_proofer).to receive(:proof).with(hash_including(state_id_address)).
            and_return(result_that_failed_instant_verify)
        end

        context 'the failure can be covered by AAMVA' do
          before do
            allow(instance).to receive(:user_can_pass_after_state_id_check?).
              with(result_that_failed_instant_verify).
              and_return(true)
            allow(result_that_failed_instant_verify).
              to receive(:attributes_requiring_additional_verification).
              and_return([:address])
          end

          context 'it is not covered by AAMVA' do
            let(:failed_aamva_proof) { instance_double(Proofing::StateIdResult) }
            before do
              allow(instance).to receive(:proof_state_id_if_needed).and_return(failed_aamva_proof)
              allow(aamva_proofer).to receive(:proof).and_return(failed_aamva_proof)
              allow(failed_aamva_proof).to receive(:verified_attributes).and_return([])
              allow(failed_aamva_proof).to receive(:success?).and_return(false)
            end
            it 'returns a failed proofing result' do
              result = subject

              expect(result.state_id_result.success?).to eq(false)
            end
          end

          context 'it is covered by AAMVA' do
            let(:successful_aamva_proof) { instance_double(Proofing::StateIdResult) }
            before do
              allow(aamva_proofer).to receive(:proof).and_return(successful_aamva_proof)
              allow(successful_aamva_proof).to receive(:verified_attributes).and_return([:address])
              allow(successful_aamva_proof).to receive(:success?).and_return(true)
            end
            it 'returns a successful proofing result' do
              result = subject

              expect(result.state_id_result.success?).to eq(true)
            end
          end
        end
      end

      context 'residential address is the same' do
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

        context 'Instant Verify fails for residential address' do
          let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer) }

          before do
            allow(instance).to receive(:state_id_proofer).and_return(aamva_proofer)
          end

          before do
            allow(instance).to receive(:proof_resolution).
              and_return(result_that_failed_instant_verify)
            allow(instant_verify_proofer).to receive(:proof).with(hash_including(state_id_address)).
              and_return(result_that_failed_instant_verify)
            allow(instance).to receive(:user_can_pass_after_state_id_check?).
              with(result_that_failed_instant_verify).
              and_return(true)
            allow(result_that_failed_instant_verify).to receive(:success?).
              and_return(false)
          end
        end
        context 'Instant Verify passes for residential address' do
        end
      end

      context 'residential address is different' do
        let(:application_pii) { Idp::Constants::MOCK_IDV_APPLICANT_ADDRESSES_DIFFER }
        let(:residential_resolution_result) do
          instance_double(Proofing::Resolution::Result)
        end

        context 'Instant Verify fails for residential address' do
          let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer) }

          before do
            allow(instance).to receive(:state_id_proofer).and_return(aamva_proofer)
            allow(instance).to receive(:proof_resolution).
              and_return(residential_resolution_result)
            allow(instant_verify_proofer).to receive(:proof).with(hash_including(state_id_address)).
              and_return(residential_resolution_result)
            allow(instance).to receive(:user_can_pass_after_state_id_check?).
              with(residential_resolution_result).
              and_return(true)
            allow(residential_resolution_result).to receive(:success?).
              and_return(true)
          end

          it 'fails adjudication logic' do
            expect(aamva_proofer).to_not receive(:proof)
            expect(instant_verify_proofer).to_not receive(:proof).with(hash_including(state_id_address))
            expect(subject.adjudicated_result.success?).to be(false) # fail adjudication logic is false
            # expect() # instant verify does not receive proof with identity doc address
            # expect() # aamva proof does not receive proof
          end
        end

        # context 'Instant Verify passes for residential address' do
        #   it 'passes adjudication logic' do
        #     expect() # aamva proof does not receive proof
        #     expect() # instant verify does not receive proof with identity doc address
        #     expect() # fail adjudication logic # state_id_result.success? is false
        #   end
        # end
      end
    end
  end
end
