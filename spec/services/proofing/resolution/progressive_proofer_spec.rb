require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
  let(:ipp_enrollment_in_progress) { false }
  let(:request_ip) { Faker::Internet.ip_v4_address }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:current_sp) { build(:service_provider) }
  let(:user_email) { Faker::Internet.email }

  let(:threatmetrix_plugin) do
    Proofing::Resolution::Plugins::ThreatMetrixPlugin.new
  end

  let(:instant_verify_state_id_address_plugin) do
    Proofing::Resolution::Plugins::InstantVerifyStateIdAddressPlugin.new
  end

  let(:instant_verify_residential_address_plugin) do
    Proofing::Resolution::Plugins::InstantVerifyResidentialAddressPlugin.new
  end

  let(:aamva_plugin) do
    Proofing::Resolution::Plugins::AamvaPlugin.new
  end

  let(:instant_verify_residential_result) do
    Proofing::Resolution::Result.new(
      success: true,
    )
  end

  let(:instant_verify_result) do
    instant_verify_residential_result
  end

  let(:aamva_result) do
    Proofing::StateIdResult.new(
      success: true,
    )
  end

  let(:threatmetrix_result) do
    Proofing::DdpResult.new(
      success: true,
    )
  end

  subject(:progressive_proofer) do
    Proofing::Resolution::ProgressiveProofer.new(
      threatmetrix: threatmetrix_plugin,
      residential_address: instant_verify_residential_address_plugin,
      resolution: instant_verify_state_id_address_plugin,
      state_id: aamva_plugin,
    )
  end

  before do
    allow(threatmetrix_plugin.proofer).to receive(:proof).and_return(threatmetrix_result)
    allow(instant_verify_state_id_address_plugin.proofer).to receive(:proof).
      and_return(instant_verify_result)
    allow(instant_verify_residential_address_plugin.proofer).to receive(:proof).
      and_return(instant_verify_residential_result)
    allow(aamva_plugin.proofer).to receive(:proof).and_return(aamva_result)
  end

  describe '#proof' do
    before do
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
    end

    subject(:proof) do
      progressive_proofer.proof(
        applicant_pii:,
        ipp_enrollment_in_progress:,
        request_ip:,
        threatmetrix_session_id:,
        timer: JobHelpers::Timer.new,
        user_email:,
        current_sp: current_sp,
      )
    end

    context 'remote unsupervised proofing' do
      it 'calls ThreatMetrixPlugin' do
        expect(threatmetrix_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          request_ip:,
          threatmetrix_session_id:,
          timer: an_instance_of(JobHelpers::Timer),
          user_email:,
        )
        proof
      end

      it 'calls InstantVerifyResidentialAddressPlugin' do
        expect(instant_verify_residential_address_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress: false,
          timer: an_instance_of(JobHelpers::Timer),
        ).and_call_original
        proof
      end

      it 'calls InstantVerifyStateIdPlugin' do
        expect(instant_verify_state_id_address_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress: false,
          instant_verify_residential_result: satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end,
          timer: an_instance_of(JobHelpers::Timer),
        ).and_call_original
        proof
      end

      it 'calls AamvaPlugin' do
        expect(aamva_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          instant_verify_result:,
          ipp_enrollment_in_progress: false,
          timer: an_instance_of(JobHelpers::Timer),
        ).and_call_original
        proof
      end

      it 'returns a ResultAdjudicator' do
        proof.tap do |result|
          expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

          expect(result.resolution_result).to eql(instant_verify_result)
          expect(result.state_id_result).to eql(aamva_result)
          expect(result.device_profiling_result).to eql(threatmetrix_result)
          expect(result.residential_resolution_result).to satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end
          expect(result.ipp_enrollment_in_progress).to eql(false)
          expect(result.same_address_as_id).to eql(nil)
        end
      end

      context 'in-person proofing' do
        let(:ipp_enrollment_in_progress) { true }
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

        context 'residential address is same as id' do
          it 'calls ThreatMetrixPlugin' do
            expect(threatmetrix_plugin).to receive(:call).with(
              applicant_pii:,
              current_sp:,
              request_ip:,
              threatmetrix_session_id:,
              timer: an_instance_of(JobHelpers::Timer),
              user_email:,
            )
            proof
          end

          it 'calls InstantVerifyResidentialAddressPlugin' do
            expect(instant_verify_residential_address_plugin).to receive(:call).with(
              applicant_pii:,
              current_sp:,
              ipp_enrollment_in_progress: true,
              timer: an_instance_of(JobHelpers::Timer),
            ).and_call_original
            proof
          end

          it 'calls InstantVerifyStateIdPlugin' do
            expect(instant_verify_state_id_address_plugin).to receive(:call).with(
              applicant_pii:,
              current_sp:,
              ipp_enrollment_in_progress: true,
              instant_verify_residential_result:,
              timer: an_instance_of(JobHelpers::Timer),
            ).and_call_original
            proof
          end

          it 'calls AamvaPlugin' do
            expect(aamva_plugin).to receive(:call).with(
              applicant_pii:,
              current_sp:,
              instant_verify_result: instant_verify_result,
              ipp_enrollment_in_progress: true,
              timer: an_instance_of(JobHelpers::Timer),
            ).and_call_original
            proof
          end

          it 'returns a ResultAdjudicator' do
            proof.tap do |result|
              expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
              expect(result.resolution_result).to eql(instant_verify_result)
              expect(result.state_id_result).to eql(aamva_result)
              expect(result.device_profiling_result).to eql(threatmetrix_result)
              expect(result.residential_resolution_result).to eql(instant_verify_residential_result)
              expect(result.ipp_enrollment_in_progress).to eql(true)
              expect(result.same_address_as_id).to eql('true')
            end
          end
        end

        context 'residential address is different than id' do
          let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_STATE_ID_ADDRESS }

          it 'calls ThreatMetrixPlugin' do
            expect(threatmetrix_plugin).to receive(:call).with(
              applicant_pii:,
              current_sp:,
              request_ip:,
              threatmetrix_session_id:,
              timer: an_instance_of(JobHelpers::Timer),
              user_email:,
            )
            proof
          end

          it 'calls InstantVerifyResidentialAddressPlugin' do
            expect(instant_verify_residential_address_plugin).to receive(:call).with(
              applicant_pii:,
              current_sp:,
              ipp_enrollment_in_progress: true,
              timer: an_instance_of(JobHelpers::Timer),
            ).and_call_original
            proof
          end

          it 'calls InstantVerifyStateIdPlugin' do
            expect(instant_verify_state_id_address_plugin).to receive(:call).with(
              applicant_pii:,
              current_sp:,
              ipp_enrollment_in_progress: true,
              instant_verify_residential_result:,
              timer: an_instance_of(JobHelpers::Timer),
            ).and_call_original
            proof
          end

          it 'calls AamvaPlugin' do
            expect(aamva_plugin).to receive(:call).with(
              applicant_pii:,
              current_sp:,
              instant_verify_result: instant_verify_result,
              ipp_enrollment_in_progress: true,
              timer: an_instance_of(JobHelpers::Timer),
            ).and_call_original
            proof
          end

          it 'returns a ResultAdjudicator' do
            proof.tap do |result|
              expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
              expect(result.resolution_result).to eql(instant_verify_result)
              expect(result.state_id_result).to eql(aamva_result)
              expect(result.device_profiling_result).to eql(threatmetrix_result)
              expect(result.residential_resolution_result).to eql(instant_verify_residential_result)
              expect(result.ipp_enrollment_in_progress).to eql(true)
              expect(result.same_address_as_id).to eql('false')
            end
          end
        end
      end
    end
  end
end
