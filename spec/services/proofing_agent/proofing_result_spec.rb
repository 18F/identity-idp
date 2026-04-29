require 'rails_helper'

RSpec.describe ProofingAgent::ProofingResult do
  let(:proofing_agent_id) { SecureRandom.uuid }
  let(:proofing_location_id) { SecureRandom.uuid }
  let(:correlation_id) { SecureRandom.uuid }
  let(:pii) { nil }
  let(:service_provider_issuer) { 'test-service-provider' }
  let(:phone_precheck_passed) { true }
  let(:resolution_result) do
    {
      success: true,
      errors: [],
      exception: nil,
      phone_precheck_passed:,
      context: {
        stages: {
          phone_precheck: { success: phone_precheck_passed, vendor_name: 'AddressMock' },
        },
      },
    }
  end
  let(:aamva_result) { {} }
  let(:mrz_result) { {} }

  subject do
    described_class.new(
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
      pii:,
      service_provider_issuer:,
      resolution_result:,
      aamva_result:,
      mrz_result:,
    )
  end

  describe '#combined_result' do
    context 'when all checks pass' do
      context 'when user has aamva check' do
        let(:aamva_result) do
          {
            success: true,
            errors: [],
            exception: nil,
            mva_exception: nil,
            requested_attributes: {},
            timed_out: false,
            transaction_id: 'abc123',
            vendor_name: 'TestVendor',
            verified_attributes: [:address, :dob, :state_id_number],
          }
        end

        it 'returns success with no reason' do
          expect(subject.combined_result).to eq(
            success: true,
            reason: nil,
            proofing_agent_id:,
            proofing_location_id:,
            correlation_id:,
            service_provider_issuer:,
            resolution: resolution_result,
            aamva: aamva_result,
          )
        end
      end

      context 'when user has mrz check' do
        let(:mrz_result) do
          DocAuth::Response.new(
            success: true,
            errors: {},
            extra: {
              vendor: 'DoS',
              correlation_id_sent: 'something',
              correlation_id_received: 'something else',
              response: 'YES',
            },
          ).to_h
        end

        it 'returns success with no reason' do
          expect(subject.combined_result).to eq(
            success: true,
            reason: nil,
            proofing_agent_id:,
            proofing_location_id:,
            correlation_id:,
            service_provider_issuer:,
            resolution: resolution_result,
            mrz: mrz_result,
          )
        end
      end
    end
  end

  context 'when resolution fails' do
    let(:resolution_result) do
      {
        success: false,
        errors: { base: ['Resolution failed'] },
        exception: nil,
        phone_precheck_passed:,
        context: {
          stages: {
            phone_precheck: { success: phone_precheck_passed, vendor_name: 'AddressMock' },
          },
        },
      }
    end
    it 'returns failure' do
      expect(subject.combined_result).to eq(
        success: false,
        reason: 'profile_resolution_fail',
        proofing_agent_id:,
        proofing_location_id:,
        correlation_id:,
        service_provider_issuer:,
        resolution: resolution_result,
      )
    end
  end

  context 'phone verification fails' do
    let(:phone_precheck_passed) { false }
    it 'returns failure' do
      expect(subject.combined_result).to eq(
        success: false,
        reason: 'phone_check_fail',
        proofing_agent_id:,
        proofing_location_id:,
        correlation_id:,
        service_provider_issuer:,
        resolution: resolution_result,
      )
    end
  end

  context 'when aamva fails' do
    let(:aamva_result) do
      {
        success: false,
        errors: { base: ['AAMVA verification failed'] },
        exception: nil,
        mva_exception: nil,
        requested_attributes: {},
        timed_out: false,
        transaction_id: 'abc123',
        vendor_name: 'TestVendor',
        verified_attributes: [:address, :dob, :state_id_number],
      }
    end

    it 'returns failure with aamva reason' do
      expect(subject.combined_result).to eq(
        success: false,
        reason: 'id_fail',
        proofing_agent_id:,
        proofing_location_id:,
        correlation_id:,
        service_provider_issuer:,
        resolution: resolution_result,
        aamva: aamva_result,
      )
    end
  end

  context 'when mrz fails' do
    let(:mrz_result) do
      DocAuth::Response.new(
        success: false,
        errors: { passport: 'invalid MRZ' },
        extra: {
          vendor: 'DoS',
          correlation_id_sent: 'something',
          correlation_id_received: 'something else',
          response: 'NO',
        },
      ).to_h
    end

    it 'returns failure with mrz reason' do
      expect(subject.combined_result).to eq(
        success: false,
        reason: 'passport_fail',
        proofing_agent_id:,
        proofing_location_id:,
        correlation_id:,
        service_provider_issuer:,
        resolution: resolution_result,
        mrz: mrz_result,
      )
    end
  end
end
