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

      let(:resolution_result) { double(Proofing::LexisNexis::InstantVerify::VerificationRequest) }
      let(:double_address_verification) { true }
      let(:state_id_address) do
        {
          address1: applicant_pii[:state_id_address1],
          address2: applicant_pii[:state_id_address2],
          city: applicant_pii[:state_id_city],
          state: applicant_pii[:state_id_state],
          state_id_jurisdiction: applicant_pii[:state_id_jurisdiction],
          zipcode: applicant_pii[:state_id_zipcode],
        }
      end
      it 'makes a request to the instant verify proofer' do
        expect(instant_verify_proofer).to receive(:proof).with(hash_including(state_id_address))
        allow(resolution_result).to receive(:success?).and_return(true)
        allow(instance).to receive(:proof_state_id_if_needed)

        subject
      end

      context 'threatmetrix is enabled' do
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

        it 'makes a request to the threatmetrix proofer' do
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

        context 'it lacks applicant pii' do
          let(:applicant_pii) { nil }
          it 'returns a disabled result' do
            result = subject

            device_profiling_result = result.device_profiling_result

            expect(device_profiling_result.success).to be(true)
            expect(device_profiling_result.client).to eq('tmx_disabled')
            expect(device_profiling_result.review_status).to eq('pass')
          end
        end
      end

      context 'threatmetrix is disabled' do
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

      context 'user is not in an AAMVA jurisdiction' do
        # Alaska is not an AAMVA jurisdiction.  Logic for this check is in resolution proofing job.
        let(:non_aamva_jurisdiction) { 'AK' }
        let(:applicant_pii_outside_aamva) do
          applicant_pii.merge(state_id_jurisdiction: non_aamva_jurisdiction)
        end
        let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer) }
        let(:should_proof_state_id) { false }

        subject(:proof) do
          instance.proof(
            applicant_pii: applicant_pii_outside_aamva,
            double_address_verification: double_address_verification,
            request_ip: request_ip,
            should_proof_state_id: should_proof_state_id,
            threatmetrix_session_id: threatmetrix_session_id,
            timer: timer,
            user_email: user.confirmed_email_addresses.first.email,
          )
        end

        it 'does not make a request to the AAMVA proofer' do
          allow(instant_verify_proofer).to receive(:proof)
          expect(aamva_proofer).to_not receive(:proof)

          response = subject

          expect(response.state_id_result.vendor_name).to eq('UnsupportedJurisdiction')
        end
      end

      context 'Instant Verify passes' do
        before do
          allow(instance).to receive(:state_id_proofer).and_return(aamva_proofer)
        end

        context 'user is in an AAMVA jurisdiction' do
          let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer) }
          let(:resolution_result_that_passes_aamva) do
            double(Proofing::LexisNexis::InstantVerify::VerificationRequest)
          end
          it 'makes a request to the AAMVA proofer' do
            allow(instance).to receive(:proof_resolution).
              and_return(resolution_result_that_passes_aamva)
            allow(instant_verify_proofer).to receive(:proof).with(hash_including(state_id_address)).
              and_return(resolution_result_that_passes_aamva)
            allow(instance).to receive(:user_can_pass_after_state_id_check?).
              with(resolution_result_that_passes_aamva).and_return(true)
            allow(resolution_result_that_passes_aamva).to receive(:success?).and_return(true)
            allow(resolution_result).to receive(:attributes_requiring_additional_verification).
              and_return([:address])

            expect(aamva_proofer).to receive(:proof)

            subject
          end
        end
      end
    end
  end
end
