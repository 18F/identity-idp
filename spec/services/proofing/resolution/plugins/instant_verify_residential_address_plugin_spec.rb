require 'rails_helper'

RSpec.describe Proofing::Resolution::Plugins::InstantVerifyResidentialAddressPlugin do
  let(:current_sp) { build(:service_provider) }

  let(:ipp_enrollment_in_progress) { false }

  let(:proofer_transaction_id) { 'residential-123' }

  let(:proofer_result) do
    Proofing::Resolution::Result.new(
      success: true,
      transaction_id: proofer_transaction_id,
      vendor_name: 'lexisnexis:instant_verify',
    )
  end

  subject(:plugin) do
    described_class.new
  end

  describe '#call' do
    def sp_cost_count_for_issuer
      SpCost.where(cost_type: :lexis_nexis_resolution, issuer: current_sp.issuer).count
    end

    def sp_cost_count_with_transaction_id
      SpCost.where(
        cost_type: :lexis_nexis_resolution,
        issuer: current_sp.issuer,
        transaction_id: proofer_transaction_id,
      ).count
    end

    subject(:call) do
      plugin.call(
        applicant_pii:,
        current_sp:,
        ipp_enrollment_in_progress:,
        timer: JobHelpers::Timer.new,
      )
    end

    before do
      allow(plugin.proofer).to receive(:proof).and_return(proofer_result)
    end

    context 'remote unsupervised proofing' do
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN }
      let(:ipp_enrollment_in_progress) { false }

      it 'returns a ResidentialAddressNotRequired result' do
        call.tap do |result|
          expect(result.success?).to eql(true)
          expect(result.vendor_name).to eql('ResidentialAddressNotRequired')
        end
      end

      it 'does not record a LexisNexis SP cost' do
        expect { call }.not_to change { sp_cost_count_for_issuer }
      end
    end

    context 'in-person proofing' do
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }
      let(:ipp_enrollment_in_progress) { true }
      let(:proofer_result) do
        Proofing::Resolution::Result.new(
          success: true,
          transaction_id: proofer_transaction_id,
          vendor_name: 'lexisnexis:instant_verify',
        )
      end

      it 'calls proofer with pii' do
        expect(plugin.proofer).to receive(:proof).with(applicant_pii)
        call
      end

      context 'when InstantVerify call succeeds' do
        it 'returns the proofer result' do
          expect(call).to eql(proofer_result)
        end

        it 'records a LexisNexis SP cost' do
          expect { call }.to change { sp_cost_count_with_transaction_id }.to(1)
        end
      end

      context 'when InstantVerify call fails' do
        let(:proofer_result) do
          Proofing::Resolution::Result.new(
            success: false,
            errors: {},
            exception: nil,
            transaction_id: proofer_transaction_id,
            vendor_name: 'lexisnexis:instant_verify',
          )
        end

        it 'returns the proofer result' do
          expect(call).to eql(proofer_result)
        end

        it 'records a LexisNexis SP cost' do
          expect { call }.to change { sp_cost_count_with_transaction_id }.to(1)
        end
      end

      context 'when InstantVerify call results in exception' do
        let(:proofer_result) do
          Proofing::Resolution::Result.new(
            success: false,
            errors: {},
            exception: RuntimeError.new(':ohno:'),
            transaction_id: proofer_transaction_id,
            vendor_name: 'lexisnexis:instant_verify',
          )
        end

        it 'returns the proofer result' do
          expect(call).to eql(proofer_result)
        end

        it 'records a LexisNexis SP cost' do
          expect { call }.to change { sp_cost_count_with_transaction_id }.to(1)
        end
      end
    end
  end

  describe '#proofer' do
    subject(:proofer) { plugin.proofer }

    before do
      allow(IdentityConfig.store).to receive(:proofer_mock_fallback).
        and_return(proofer_mock_fallback)
      allow(IdentityConfig.store).to receive(:idv_resolution_default_vendor).
        and_return(idv_resolution_default_vendor)
    end

    context 'when proofer_mock_fallback is set to true' do
      let(:proofer_mock_fallback) { true }

      context 'and idv_resolution_default_vendor is set to :instant_verify' do
        let(:idv_resolution_default_vendor) do
          :instant_verify
        end

        # rubocop:disable Layout/LineLength
        it 'creates an Instant Verify proofer because the new setting takes precedence over the old one when the old one is set to its default value' do
          expect(proofer).to be_an_instance_of(Proofing::LexisNexis::InstantVerify::Proofer)
        end
        # rubocop:enable Layout/LineLength
      end

      context 'and idv_resolution_default_vendor is set to :mock' do
        let(:idv_resolution_default_vendor) { :mock }

        it 'creates a mock proofer because the two settings agree' do
          expect(proofer).to be_an_instance_of(Proofing::Mock::ResolutionMockClient)
        end
      end
    end

    context 'when proofer_mock_fallback is set to false' do
      let(:proofer_mock_fallback) { false }

      context 'and idv_resolution_default_vendor is set to :instant_verify' do
        let(:idv_resolution_default_vendor) { :instant_verify }

        it 'creates an Instant Verify proofer because the two settings agree' do
          expect(proofer).to be_an_instance_of(Proofing::LexisNexis::InstantVerify::Proofer)
        end
      end

      context 'and idv_resolution_default_vendor is set to :mock' do
        let(:idv_resolution_default_vendor) { :mock }

        it 'creates an Instant Verify proofer to support transition between configs' do
          expect(proofer).to be_an_instance_of(Proofing::LexisNexis::InstantVerify::Proofer)
        end
      end
    end
  end
end
