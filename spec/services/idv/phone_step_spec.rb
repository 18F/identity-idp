require 'rails_helper'

describe Idv::PhoneStep do
  include Features::LocalizationHelper

  let(:user) { build(:user) }
  let(:idv_session) do
    idvs = Idv::Session.new(user_session: {}, current_user: user, issuer: nil)
    idvs.applicant = { first_name: 'Some' }
    idvs
  end
  let(:idv_form_params) { { phone: '555-555-0000', phone_confirmed_at: nil } }
  let(:idv_phone_form) { Idv::PhoneForm.new(idv_session.params, user) }

  def build_step(vendor_validator_result)
    described_class.new(
      idv_session: idv_session,
      idv_form_params: idv_form_params,
      vendor_validator_result: vendor_validator_result
    )
  end

  describe '#submit' do
    let(:context) { 'some context' }

    it 'returns true for mock-happy phone' do
      step = build_step(
        Idv::VendorResult.new(
          success: true,
          errors: {},
          context: context
        )
      )

      result = step.submit

      expect(result).to be_kind_of(FormResponse)
      expect(result.success?).to eq(true)
      expect(result.errors).to be_empty
      expect(idv_session.vendor_phone_confirmation).to eq true
      expect(idv_session.params).to eq idv_phone_form.idv_params
      expect(result.extra).to include(
        vendor: {
          messages: [],
          context: context,
          exception: nil,
        }
      )
    end

    it 'returns false for mock-sad phone' do
      idv_form_params[:phone] = '555-555-5555'
      errors = { phone: ['The phone number could not be verified.'] }

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
      expect(idv_session.vendor_phone_confirmation).to eq false
    end

    it 'marks the phone number as confirmed by user if it matches 2FA phone' do
      idv_form_params[:phone_confirmed_at] = Time.zone.now
      step = build_step(
        Idv::VendorResult.new(
          success: true,
          errors: {}
        )
      )
      step.submit

      expect(idv_session.user_phone_confirmation).to eq(true)
    end

    it 'does not mark the phone number as confirmed by user if it does not match 2FA phone' do
      step = build_step(
        Idv::VendorResult.new(
          success: true,
          errors: {}
        )
      )
      step.submit

      expect(idv_session.user_phone_confirmation).to eq(false)
    end
  end
end
