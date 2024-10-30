require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
  let(:ipp_enrollment_in_progress) { false }
  let(:request_ip) { Faker::Internet.ip_v4_address }
  let(:threatmetrix_session_id) { SecureRandom.uuid }
  let(:user_email) { Faker::Internet.email }
  let(:current_sp) { build(:service_provider) }

  let(:instant_verify_residential_address_plugin) do
    Proofing::Resolution::Plugins::InstantVerifyResidentialAddressPlugin.new
  end

  let(:instant_verify_residential_address_result) do
    Proofing::Resolution::Result.new(
      success: true,
      transaction_id: 'iv-residential',
    )
  end

  let(:instant_verify_residential_address_proofer) do
    instance_double(
      Proofing::LexisNexis::InstantVerify::Proofer,
      proof: instant_verify_residential_address_result,
    )
  end

  let(:instant_verify_state_id_address_plugin) do
    Proofing::Resolution::Plugins::InstantVerifyStateIdAddressPlugin.new
  end

  let(:instant_verify_state_id_address_result) do
    Proofing::Resolution::Result.new(
      success: true,
      transaction_id: 'iv-state-id',
    )
  end

  let(:instant_verify_state_id_address_proofer) do
    instance_double(
      Proofing::LexisNexis::InstantVerify::Proofer,
      proof: instant_verify_state_id_address_result,
    )
  end

  let(:aamva_plugin) { Proofing::Resolution::Plugins::AamvaPlugin.new }

  let(:aamva_result) do
    Proofing::StateIdResult.new(
      success: false,
      transaction_id: 'aamva-123',
    )
  end

  let(:aamva_proofer) { instance_double(Proofing::Aamva::Proofer, proof: aamva_result) }

  let(:threatmetrix_plugin) do
    Proofing::Resolution::Plugins::ThreatMetrixPlugin.new
  end

  let(:threatmetrix_result) do
    Proofing::DdpResult.new(
      success: true,
      transaction_id: 'ddp-123',
    )
  end

  let(:threatmetrix_proofer) do
    instance_double(
      Proofing::LexisNexis::Ddp::Proofer,
      proof: threatmetrix_result,
    )
  end

  subject(:progressive_proofer) { described_class.new }

  before do
    allow(progressive_proofer).to receive(:threatmetrix_plugin).and_return(threatmetrix_plugin)
    allow(threatmetrix_plugin).to receive(:proofer).and_return(threatmetrix_proofer)

    allow(progressive_proofer).to receive(:aamva_plugin).and_return(aamva_plugin)
    allow(aamva_plugin).to receive(:proofer).and_return(aamva_proofer)

    allow(progressive_proofer).to receive(:instant_verify_residential_address_plugin).
      and_return(instant_verify_residential_address_plugin)
    allow(instant_verify_residential_address_plugin).to receive(:proofer).
      and_return(instant_verify_residential_address_proofer)

    allow(progressive_proofer).to receive(:instant_verify_state_id_address_plugin).
      and_return(instant_verify_state_id_address_plugin)
    allow(instant_verify_state_id_address_plugin).to receive(:proofer).
      and_return(instant_verify_state_id_address_proofer)
  end

  it 'assigns aamva_plugin' do
    expect(described_class.new.aamva_plugin).to be_a(
      Proofing::Resolution::Plugins::AamvaPlugin,
    )
  end

  it 'assigns instant_verify_residential_address_plugin' do
    expect(described_class.new.instant_verify_residential_address_plugin).to be_a(
      Proofing::Resolution::Plugins::InstantVerifyResidentialAddressPlugin,
    )
  end

  it 'assigns instant_verify_state_id_address_plugin' do
    expect(described_class.new.instant_verify_state_id_address_plugin).to be_a(
      Proofing::Resolution::Plugins::InstantVerifyStateIdAddressPlugin,
    )
  end

  it 'assigns threatmetrix_plugin' do
    expect(described_class.new.threatmetrix_plugin).to be_a(
      Proofing::Resolution::Plugins::ThreatMetrixPlugin,
    )
  end

  describe '#proof' do
    subject(:proof) do
      progressive_proofer.proof(
        applicant_pii:,
        ipp_enrollment_in_progress:,
        request_ip:,
        threatmetrix_session_id:,
        timer: JobHelpers::Timer.new,
        user_email:,
        current_sp:,
      )
    end

    context 'remote unsupervised proofing' do
      it 'calls AamvaPlugin' do
        expect(aamva_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          instant_verify_state_id_address_result:,
          ipp_enrollment_in_progress: false,
          timer: an_instance_of(JobHelpers::Timer),
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

      it 'calls InstantVerifyStateIdAddressPlugin' do
        expect(instant_verify_state_id_address_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          instant_verify_residential_address_result: satisfy do |result|
            expect(result.success?).to eql(true)
            expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
          end,
          ipp_enrollment_in_progress: false,
          timer: an_instance_of(JobHelpers::Timer),
        ).and_call_original
        proof
      end

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

      it 'returns a ResultAdjudicator' do
        proof.tap do |result|
          expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

          expect(result.resolution_result).to eql(instant_verify_state_id_address_result)
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
    end

    context 'in-person proofing' do
      let(:ipp_enrollment_in_progress) { true }

      context 'residential address is same as id' do
        let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }

        let(:instant_verify_state_id_address_result) do
          instant_verify_residential_address_result
        end

        it 'calls AamvaPlugin' do
          expect(aamva_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            instant_verify_state_id_address_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
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

        it 'calls InstantVerifyStateIdAddressPlugin' do
          expect(instant_verify_state_id_address_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            instant_verify_residential_address_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

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

        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)

            expect(result.resolution_result).to eql(instant_verify_state_id_address_result)
            expect(result.state_id_result).to eql(aamva_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.residential_resolution_result).to(
              eql(instant_verify_state_id_address_result),
            )
            expect(result.ipp_enrollment_in_progress).to eql(true)
            expect(proof.same_address_as_id).to eq(applicant_pii[:same_address_as_id])
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

        it 'calls InstantVerifyStateIdAddressPlugin' do
          expect(instant_verify_state_id_address_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            instant_verify_residential_address_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'calls AamvaPlugin' do
          expect(aamva_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            instant_verify_state_id_address_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.resolution_result).to eql(instant_verify_state_id_address_result)
            expect(result.state_id_result).to eql(aamva_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.residential_resolution_result).to(
              eql(instant_verify_residential_address_result),
            )
            expect(result.ipp_enrollment_in_progress).to eql(true)
            expect(result.same_address_as_id).to eql('false')
          end
        end
      end
    end

    context 'when applicant_pii includes best_effort_phone_number_for_socure' do
      let(:applicant_pii) do
        Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.merge(
          best_effort_phone_number_for_socure: '3608675309',
        )
      end

      it 'does not pass the phone number to plugins' do
        expected_applicant_pii = applicant_pii.except(:best_effort_phone_number_for_socure)

        [
          aamva_plugin,
          instant_verify_residential_address_plugin,
          instant_verify_state_id_address_plugin,
          threatmetrix_plugin,
        ].each do |plugin|
          expect(plugin).to receive(:call).with(
            hash_including(
              applicant_pii: expected_applicant_pii,
            ),
          ).and_call_original
        end

        proof
      end
    end
  end
end
