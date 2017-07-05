require 'rails_helper'

describe Idv::FinancialsStep do
  let(:user) { build(:user) }
  let(:idv_session) do
    idvs = Idv::Session.new(user_session: {}, current_user: user, issuer: nil)
    idvs.vendor = :mock
    idvs
  end
  let(:idv_form_params) { idv_session.params }

  def build_step(vendor_validator_result)
    described_class.new(
      idv_form_params: idv_form_params,
      idv_session: idv_session,
      vendor_validator_result: vendor_validator_result
    )
  end

  describe '#submit' do
    it 'returns FormResponse with success: true for mock-happy CCN' do
      step = build_step(
        Idv::VendorResult.new(
          success: true,
          errors: {}
        )
      )

      result = step.submit
      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty

      expect(idv_session.financials_confirmation).to eq true
      expect(idv_session.params).to eq idv_form_params
    end

    it 'returns FormResponse with success: false for mock-sad CCN' do
      errors = { ccn: ['The ccn could not be verified.'] }

      step = build_step(
        Idv::VendorResult.new(
          success: false,
          errors: errors
        )
      )

      result = step.submit
      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)

      expect(idv_session.financials_confirmation).to eq false
    end
  end
end
