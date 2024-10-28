require 'rails_helper'

RSpec.describe Proofing::Resolution::Plugins::InstantVerifyResidentialAddressPlugin do
  let(:current_sp) { build(:service_provider) }

  let(:ipp_enrollment_in_progress) { false }

  let(:proofer_result) do
    Proofing::Resolution::Result.new(
      success: true,
      errors: {},
      exception: nil,
      vendor_name: 'lexisnexis:instant_verify',
    )
  end

  subject(:plugin) do
    described_class.new
  end

  before do
    allow(plugin.proofer).to receive(:proof).and_return(proofer_result)
  end

  describe '#call' do
    subject(:call) do
      plugin.call(
        applicant_pii:,
        current_sp:,
        ipp_enrollment_in_progress:,
        timer: JobHelpers::Timer.new,
      )
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
    end

    context 'in-person proofing' do
      let(:applicant_pii) { Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID }
      let(:ipp_enrollment_in_progress) { true }

      it 'calls proofer with pii' do
        expect(plugin.proofer).to receive(:proof).with(applicant_pii)
        call
      end

      context 'when InstantVerify call succeeds' do
        it 'returns the proofer result' do
          expect(call).to eql(proofer_result)
        end

        it 'records a LexisNexis SP cost' do
          expect { call }.
            to change {
                 SpCost.where(
                   cost_type: :lexis_nexis_resolution,
                   issuer: current_sp.issuer,
                 ).count
               }.to(1)
        end
      end

      context 'when InstantVerify call fails' do
        let(:proofer_result) do
          Proofing::Resolution::Result.new(
            success: false,
            errors: {},
            exception: nil,
            vendor_name: 'lexisnexis:instant_verify',
          )
        end

        it 'returns the proofer result' do
          expect(call).to eql(proofer_result)
        end

        it 'records a LexisNexis SP cost' do
          expect { call }.
            to change {
                 SpCost.where(
                   cost_type: :lexis_nexis_resolution,
                   issuer: current_sp.issuer,
                 ).count
               }.to(1)
        end
      end

      context 'when InstantVerify call results in exception' do
        let(:proofer_result) do
          Proofing::Resolution::Result.new(
            success: false,
            errors: {},
            exception: RuntimeError.new(':ohno:'),
            vendor_name: 'lexisnexis:instant_verify',
          )
        end

        it 'returns the proofer result' do
          expect(call).to eql(proofer_result)
        end

        it 'records a LexisNexis SP cost' do
          expect { call }.
            to change {
                 SpCost.where(
                   cost_type: :lexis_nexis_resolution,
                   issuer: current_sp.issuer,
                 ).count
               }.to(1)
        end
      end
    end
  end
end
