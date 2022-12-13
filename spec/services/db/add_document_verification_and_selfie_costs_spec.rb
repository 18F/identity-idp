require 'rails_helper'

describe Db::AddDocumentVerificationAndSelfieCosts do
  let(:user_id) { 1 }
  let(:service_provider) { build(:service_provider, issuer: 'foo') }
  let(:billed_response) do
    DocAuth::Response.new(
      success: true,
      errors: [],
      pii_from_doc: {},
      extra: {
        doc_auth_result: 'Passed',
        billed: true,
      },
    )
  end
  let(:not_billed_response) do
    DocAuth::Response.new(
      success: true,
      errors: [],
      pii_from_doc: {},
      extra: {
        doc_auth_result: 'Passed',
        billed: false,
      },
    )
  end

  subject do
    described_class.new(
      user_id: user_id,
      service_provider: service_provider,
    )
  end

  it 'has costing for front, back, and result when billed' do
    subject.call(billed_response)

    expect(costing_for(:acuant_front_image)).to be_present
    expect(costing_for(:acuant_back_image)).to be_present
    expect(costing_for(:acuant_result)).to be_present
    expect(costing_for(:acuant_selfie)).to be_nil
  end

  it 'has costing for front, back, but not result when not billed' do
    subject.call(not_billed_response)

    expect(costing_for(:acuant_front_image)).to be_present
    expect(costing_for(:acuant_back_image)).to be_present
    expect(costing_for(:acuant_result)).to be_nil
    expect(costing_for(:acuant_selfie)).to be_nil
  end

  def costing_for(cost_type)
    SpCost.where(
      ial: 2,
      issuer: service_provider.issuer,
      agency_id: service_provider.agency_id,
      cost_type: cost_type.to_s,
    ).first
  end
end
