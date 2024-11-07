require 'rails_helper'

RSpec.describe Proofing::Resolution::ProgressiveProofer do
  subject(:progressive_proofer) { described_class.new }

  it 'assigns aamva_plugin' do
    expect(progressive_proofer.aamva_plugin).to be_a(
      Proofing::Resolution::Plugins::AamvaPlugin,
    )
  end

  it 'assigns threatmetrix_plugin' do
    expect(progressive_proofer.threatmetrix_plugin).to be_a(
      Proofing::Resolution::Plugins::ThreatMetrixPlugin,
    )
  end

  describe '#proof' do
    let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
    let(:ipp_enrollment_in_progress) { false }
    let(:request_ip) { Faker::Internet.ip_v4_address }
    let(:threatmetrix_session_id) { SecureRandom.uuid }
    let(:user_email) { Faker::Internet.email }
    let(:current_sp) { build(:service_provider) }
    let(:sp_cost_token) { :mock_resolution }

    let(:residential_address_plugin) do
      Proofing::Resolution::Plugins::ResidentialAddressPlugin.new(
        proofer: residential_address_proofer,
        sp_cost_token:,
      )
    end

    let(:residential_address_resolution_result) do
      Proofing::Resolution::Result.new(
        success: true,
        transaction_id: 'iv-residential',
      )
    end

    let(:residential_address_proofer) do
      instance_double(
        Proofing::LexisNexis::InstantVerify::Proofer,
        proof: residential_address_resolution_result,
      )
    end

    let(:state_id_address_plugin) do
      Proofing::Resolution::Plugins::StateIdAddressPlugin.new(
        proofer: state_id_address_proofer,
        sp_cost_token:,
      )
    end

    let(:state_id_address_resolution_result) do
      Proofing::Resolution::Result.new(
        success: true,
        transaction_id: 'iv-state-id',
      )
    end

    let(:state_id_address_proofer) do
      instance_double(
        Proofing::LexisNexis::InstantVerify::Proofer,
        proof: state_id_address_resolution_result,
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

    before do
      allow(progressive_proofer).to receive(:threatmetrix_plugin).and_return(threatmetrix_plugin)
      allow(threatmetrix_plugin).to receive(:proofer).and_return(threatmetrix_proofer)

      allow(progressive_proofer).to receive(:aamva_plugin).and_return(aamva_plugin)
      allow(aamva_plugin).to receive(:proofer).and_return(aamva_proofer)

      allow(progressive_proofer).to receive(:residential_address_plugin).
        and_return(residential_address_plugin)
      allow(residential_address_plugin).to receive(:proofer).
        and_return(residential_address_proofer)

      allow(progressive_proofer).to receive(:state_id_address_plugin).
        and_return(state_id_address_plugin)
      allow(state_id_address_plugin).to receive(:proofer).
        and_return(state_id_address_proofer)
    end

    context 'remote unsupervised proofing' do
      it 'calls AamvaPlugin' do
        expect(aamva_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result:,
          ipp_enrollment_in_progress: false,
          timer: an_instance_of(JobHelpers::Timer),
        )
        proof
      end

      it 'calls ResidentialAddressPlugin' do
        expect(residential_address_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress: false,
          timer: an_instance_of(JobHelpers::Timer),
        ).and_call_original
        proof
      end

      it 'calls StateIdAddressPlugin' do
        expect(state_id_address_plugin).to receive(:call).with(
          applicant_pii:,
          current_sp:,
          residential_address_resolution_result: satisfy do |result|
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

          expect(result.resolution_result).to eql(state_id_address_resolution_result)
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

        let(:state_id_address_resolution_result) do
          residential_address_resolution_result
        end

        it 'calls AamvaPlugin' do
          expect(aamva_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            state_id_address_resolution_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          )

          proof
        end

        it 'calls ResidentialAddressPlugin' do
          expect(residential_address_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'calls StateIdAddressPlugin' do
          expect(state_id_address_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            residential_address_resolution_result:,
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

            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.state_id_result).to eql(aamva_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.residential_resolution_result).to(
              eql(state_id_address_resolution_result),
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

        it 'calls ResidentialAddressPlugin' do
          expect(residential_address_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'calls StateIdAddressPlugin' do
          expect(state_id_address_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            residential_address_resolution_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'calls AamvaPlugin' do
          expect(aamva_plugin).to receive(:call).with(
            applicant_pii:,
            current_sp:,
            state_id_address_resolution_result:,
            ipp_enrollment_in_progress: true,
            timer: an_instance_of(JobHelpers::Timer),
          ).and_call_original
          proof
        end

        it 'returns a ResultAdjudicator' do
          proof.tap do |result|
            expect(result).to be_an_instance_of(Proofing::Resolution::ResultAdjudicator)
            expect(result.resolution_result).to eql(state_id_address_resolution_result)
            expect(result.state_id_result).to eql(aamva_result)
            expect(result.device_profiling_result).to eql(threatmetrix_result)
            expect(result.residential_resolution_result).to(
              eql(residential_address_resolution_result),
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
          residential_address_plugin,
          state_id_address_plugin,
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

  describe '#proofing_vendor' do
    let(:idv_resolution_default_vendor) { :default_vendor }
    let(:idv_resolution_alternate_vendor) { :alternate_vendor }
    let(:idv_resolution_alternate_vendor_percent) { 0 }

    subject(:proofing_vendor) { progressive_proofer.proofing_vendor }

    before do
      allow(IdentityConfig.store).to receive(:idv_resolution_default_vendor).
        and_return(idv_resolution_default_vendor)
      allow(IdentityConfig.store).to receive(:idv_resolution_alternate_vendor).
        and_return(idv_resolution_alternate_vendor)
      allow(IdentityConfig.store).to receive(:idv_resolution_alternate_vendor_percent).
        and_return(idv_resolution_alternate_vendor_percent)
    end

    context 'when default is set to 100%' do
      it 'uses the default' do
        expect(proofing_vendor).to eql(:default_vendor)
      end
    end

    context 'when alternate is set to 100%' do
      let(:idv_resolution_alternate_vendor_percent) { 100 }

      it 'uses the alternate' do
        expect(proofing_vendor).to eql(:alternate_vendor)
      end
    end

    context 'when default is not configured' do
      let(:idv_resolution_default_vendor) { nil }

      it 'raises an error' do
        expect { proofing_vendor }.to raise_error('idv_resolution_default_vendor not configured')
      end
    end

    context 'when proofer_mock_fallback is false' do
      before do
        allow(IdentityConfig.store).to receive(:proofer_mock_fallback).and_return(false)
      end

      context 'and default is set to :mock' do
        let(:idv_resolution_default_vendor) { :mock }

        it 'uses instant_verify' do
          expect(proofing_vendor).to eql(:instant_verify)
        end
      end

      context 'and default is set to a value other than :mock' do
        let(:idv_resolution_default_vendor) { :default }

        it 'uses the other value' do
          expect(proofing_vendor).to eql(:default)
        end
      end
    end

    context 'when alternate is not configured' do
      let(:idv_resolution_alternate_vendor) { nil }
      it 'uses default' do
        expect(proofing_vendor).to eql(:default_vendor)
      end

      context 'and alternate is set to > 0' do
        let(:idv_resolution_alternate_vendor_percent) { 50 }
        it 'raises error' do
          expect { proofing_vendor }.to(
            # rubocop:disable Layout/LineLength
            raise_error('idv_resolution_alternate_vendor is not configured, but idv_resolution_alternate_vendor_percent is > 0'),
            # rubocop:enable Layout/LineLength
          )
        end
      end
    end
  end

  describe '#residential_address_plugin' do
    let(:proofing_vendor) { nil }

    before do
      allow(progressive_proofer).to receive(:proofing_vendor).and_return(proofing_vendor)
    end

    context 'when proofing_vendor is :instant_verify' do
      let(:proofing_vendor) { :instant_verify }

      it 'returns ResidentialAddressPlugin with an InstantVerify proofer' do
        expect(progressive_proofer.residential_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::ResidentialAddressPlugin,
        )

        expect(progressive_proofer.residential_address_plugin.proofer).to be_an_instance_of(
          Proofing::LexisNexis::InstantVerify::Proofer,
        )
      end
    end

    context 'when proofing_vendor is :mock' do
      let(:proofing_vendor) { :mock }

      it 'returns ResidentialAddressPlugin with a mock proofer' do
        expect(progressive_proofer.residential_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::ResidentialAddressPlugin,
        )

        expect(progressive_proofer.residential_address_plugin.proofer).to be_an_instance_of(
          Proofing::Mock::ResolutionMockClient,
        )
      end
    end

    context 'when proofing_vendor is :socure' do
      let(:proofing_vendor) { :socure }

      it 'returns ResidentialAddressPlugin with a Socure proofer' do
        expect(progressive_proofer.residential_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::ResidentialAddressPlugin,
        )

        expect(progressive_proofer.residential_address_plugin.proofer).to be_an_instance_of(
          Proofing::Socure::IdPlus::Proofer,
        )
      end
    end

    context 'when proofing_vendor is another value' do
      let(:proofing_vendor) { :a_dog }

      it 'raises an error' do
        expect { progressive_proofer.residential_address_plugin }.to raise_error
      end
    end
  end

  describe '#state_id_address_plugin' do
    let(:proofing_vendor) { nil }

    before do
      allow(progressive_proofer).to receive(:proofing_vendor).and_return(proofing_vendor)
    end

    context 'when proofing_vendor is :instant_verify' do
      let(:proofing_vendor) { :instant_verify }

      it 'returns StateIdAddressPlugin with an InstantVerify proofer' do
        expect(progressive_proofer.state_id_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::StateIdAddressPlugin,
        )

        expect(progressive_proofer.state_id_address_plugin.proofer).to be_an_instance_of(
          Proofing::LexisNexis::InstantVerify::Proofer,
        )
      end
    end

    context 'when proofing_vendor is :socure' do
      let(:proofing_vendor) { :socure }

      it 'returns StateIdAddressPlugin with a Socure proofer' do
        expect(progressive_proofer.state_id_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::StateIdAddressPlugin,
        )

        expect(progressive_proofer.state_id_address_plugin.proofer).to be_an_instance_of(
          Proofing::Socure::IdPlus::Proofer,
        )
      end
    end

    context 'when proofing_vendor is :mock' do
      let(:proofing_vendor) { :mock }

      it 'returns StateIdAddressPlugin with a mock proofer' do
        expect(progressive_proofer.state_id_address_plugin).to be_an_instance_of(
          Proofing::Resolution::Plugins::StateIdAddressPlugin,
        )

        expect(progressive_proofer.state_id_address_plugin.proofer).to be_an_instance_of(
          Proofing::Mock::ResolutionMockClient,
        )
      end
    end

    context 'when proofing_vendor is another value' do
      let(:proofing_vendor) { :🦨 }

      it 'raises an error' do
        expect { progressive_proofer.state_id_address_plugin }.to raise_error
      end
    end
  end
end
