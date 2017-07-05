require 'rails_helper'

describe Idv::PhoneStep do
  include Features::LocalizationHelper

  let(:user) { build(:user) }
  let(:idv_session) do
    idvs = Idv::Session.new(user_session: {}, current_user: user, issuer: nil)
    idvs.vendor = :mock
    idvs.applicant = Proofer::Applicant.new first_name: 'Some'
    idvs
  end
  let(:idv_phone_form) { Idv::PhoneForm.new(idv_session.params, user) }

  def build_step(phone, vendor_validator_result)
    described_class.new(
      idv_session: idv_session,
      idv_form_params: { phone: phone },
      vendor_validator_result: vendor_validator_result
    )
  end

  describe '#submit' do
    it 'returns true for mock-happy phone' do
      step = build_step(
        '555-555-0000',
        Idv::VendorResult.new(
          success: true,
          errors: {}
        )
      )

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty
      expect(idv_session.phone_confirmation).to eq true
      expect(idv_session.params).to eq idv_phone_form.idv_params
    end

    it 'returns false for mock-sad phone' do
      errors = { phone: ['The phone number could not be verified.'] }

      step = build_step(
        '555-555-5555',
        Idv::VendorResult.new(
          success: false,
          errors: errors
        )
      )

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(false)
      expect(result.errors).to eq(errors)
      expect(idv_session.phone_confirmation).to eq false
    end
  end
end
