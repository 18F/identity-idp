require 'rails_helper'

RSpec.describe SocureReasonCode do
  let(:code) { 'I831' }
  let(:description) { 'Document is valid' }
  let(:deactivated_code) { 'R810' }
  let(:deactivated_description) { 'Document is expired' }
  let(:unknown_code) { 'Z999' }

  let!(:reason_code) { create(:socure_reason_code, code:, description:) }
  let!(:deactivated_reason_code) do
    create(
      :socure_reason_code,
      :deactivated,
      code: deactivated_code,
      description: deactivated_description,
    )
  end

  describe '.active' do
    it 'includes reason codes that have not been deactivated' do
      expect(SocureReasonCode.active).to include(reason_code)
    end

    it 'excludes reason codes that have been deactivated' do
      expect(SocureReasonCode.active).not_to include(deactivated_reason_code)
    end
  end

  describe '.with_definitions' do
    it 'maps known reason codes to their descriptions' do
      expect(SocureReasonCode.with_definitions([code])).to eq(code => description)
    end

    it 'maps unknown reason codes to UNKNOWN_REASON_CODE' do
      expect(SocureReasonCode.with_definitions([unknown_code])).to eq(
        unknown_code => SocureReasonCode::UNKNOWN_REASON_CODE,
      )
    end

    it 'maps a mix of known and unknown reason codes' do
      expect(SocureReasonCode.with_definitions([code, unknown_code])).to eq(
        code => description,
        unknown_code => SocureReasonCode::UNKNOWN_REASON_CODE,
      )
    end

    it 'returns an empty hash when given no reason codes' do
      expect(SocureReasonCode.with_definitions([])).to eq({})
    end

    it 'maps deactivated reason codes to their descriptions' do
      expect(SocureReasonCode.with_definitions([deactivated_code])).to eq(
        deactivated_code => deactivated_description,
      )
    end
  end
end
